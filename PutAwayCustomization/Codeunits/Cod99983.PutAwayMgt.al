namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;
using Microsoft.Inventory.Item;

/// <summary>
/// US 40488 — Goods-In Put-Away routing engine.
///
/// PURPOSE
///   When stock is received at the Receive Location (PICK BULK), route the
///   put-away line to the Receive staging bins that serve the item's Main-WH
///   pick faces:
///
///     BULK              -> Bulk (BULK DECANT) bin
///     Static / Flowrack -> Flowrack (GEN DECANT) bin
///     remainder         -> HighBay bin
///
///   ROUTING TYPES ARE DERIVED FROM BIN CONTENT, not from a field on Item.
///   An item's types are the Main-WH routing bins it holds Bin Content in, so
///   ONE ITEM MAY BE SEVERAL TYPES AT ONCE (a BULK reserve pallet and a
///   Flowrack pick face). The former Item."Routing Type" enum could hold only
///   one value and silently reported the first, so the second type's capacity
///   was never considered and stock went to HighBay while a valid pick face
///   stood empty.
///
///   A receipt therefore yields ONE PLACE LINE PER STAGING BIN, in the fill
///   order from Warehouse Setup ("Routing Priority 1..3", default
///   BULK -> Static -> Flowrack), plus a HighBay line for any remainder:
///
///     120 units, BULK holds 50, GEN DECANT holds 30
///       -> Place line 1:  50 -> BULK DECANT
///       -> Place line 2:  30 -> GEN DECANT
///       -> Place line 3:  40 -> HIGH BAY
///
///   At put-away, Static and Flowrack items share the GEN DECANT bin, so a
///   dual Static+Flowrack item produces ONE line there whose capacity is the
///   SUM of its Static Max-Qty space and its Flowrack tote space. The
///   Static-vs-Flowrack split is resolved later, during the decant phase.
///
///   Routing booleans live on Bin (Bulk / Static / Flowrack / HighBay).
///
/// HIGH-LEVEL RULES
///   1. Only triggers at the configured Receive Location.
///   2. Only acts on Put-Away Place lines from a Purchase Order source.
///   3. Master-data gate: if the item holds NO Bin Content in any Main-WH
///      routing bin, it has no routing type at all and the entire line goes to
///      HighBay. Items without configured master data must not land on an
///      unmanaged decant.
///   4. BULK Min-Qty top-up bypass: for BULK items, if on-hand qty across the
///      Main-WH and Receive BULK DECANT bins is below the Main-WH bin's Min
///      Qty, the line is routed to BULK DECANT regardless of expiry. The
///      Max-Qty cap in HandleBinCapacity still splits overflow to HighBay.
///   5. Expiry check (when not bypassed): if incoming line's expiry is NEWER
///      than the latest existing expiry already in the target bin, the entire
///      line is sent to HighBay (the decant face must keep the freshest stock).
///   6. If routing the line to the target staging bin would exceed the
///      capacity behind it, the line is split: the spillover CASCADES to the
///      next staging bin in the item's fill order, splitting again as needed,
///      and only the final remainder goes to HighBay.
/// </summary>
codeunit 99983 "Put-Away Mgt. NDPP"
{

    // SingleInstance is required so G_LineSpacing is visible to the
    // OnSplitLineOnBeforeRenumberAllLines subscriber during SplitLine() calls.
    SingleInstance = true;
    Permissions = tabledata "Warehouse Activity Line" = rm,
                  tabledata "Bin Content" = r,
                  tabledata Bin = r,
                  tabledata Item = r;

    /// <summary>
    /// Routes a freshly-created Put-Away line to its target bin.
    /// Called from OnBeforeWhseActivLineInsert subscriber.
    /// </summary>
    procedure RoutePutAwayLine(var WhseActivityLine: Record "Warehouse Activity Line")
    var
        IsHandled: Boolean;
        LastDecantExpiry: Date;
        EarliestHighBayExpiry: Date;
        TargetType: Enum "Put-Away Target Zone NDPP";
        StagingTypes: List of [Enum "Put-Away Target Zone NDPP"];
        ScopeKey: Text;
        MainShortfall: Decimal;
        HighBayOlderQty: Decimal;
        NetShortfall: Decimal;
    begin
        OnBeforeRoutePutAwayLine(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        // Reset claims when the (Put-Away Doc No., Item No.) scope changes.
        //
        // Why not OnBeforeCode of cod 7313: standard BC calls cod 7313 .Run()
        // once per Posted Whse. Receipt Line, so an OnBeforeCode reset would
        // wipe claims between receipt lines of the same put-away document.
        //
        // Why include Item No. in the scope: claims should accumulate while
        // we're routing lots of THE SAME item (so each lot picks a different
        // Main bin), and start fresh as soon as a different item arrives. The
        // doc-no. half of the key also stops claims leaking between two
        // put-aways processed back-to-back in the same session.
        ScopeKey := WhseActivityLine."No." + '|' + WhseActivityLine."Item No.";
        if ScopeKey <> G_ClaimScopeKey then begin
            Clear(G_TargetedBins);
            //G_CurrentLineMainBin := '';
            G_ClaimScopeKey := ScopeKey;
            // The net-shortfall cap is scoped to one (Doc No. | Item No.) run too —
            // a cap computed for a previous item must never bound this one.
            G_NetShortfallCap := 0;
            G_NetShortfallScopeKey := '';
        end;

        // Already in the High-Bay bin — leave alone.
        if IsLineInHighBay(WhseActivityLine) then
            exit;

        // Defensive: prior runs of HandleBinCapacity that exited mid-split could
        // theoretically leave G_LineSpacing stuck at TRUE — reset on every entry.
        G_LineSpacing := false;

        // 1. Decide the initial staging bin from the item's routing types, which
        //    are derived from the Main-WH bins it holds Bin Content in. An item
        //    may be several types at once; the first in fill order wins the
        //    first Place line, and HandleBinCapacity spills the remainder to the
        //    next staging bin (and finally High Bay).
        //
        // 2. Master-data gate: an empty list means the item has no routing bins
        //    in Main WH at all — unconfigured. Route everything to HighBay
        //    rather than onto a decant face with no Min / Max / Number of Totes.
        StagingTypes := GetStagingTypesForItem(WhseActivityLine."Item No.");
        if StagingTypes.Count() = 0 then begin
            AssignTargetBin(WhseActivityLine, TargetType::HighBay);
            OnAfterRoutePutAwayLine(WhseActivityLine);
            exit;
        end;
        TargetType := StagingTypes.Get(1);

        // 3a. HighBay older-stock guard (FEFO trumps everything else):
        //     If Receive's HighBay already holds positive-qty stock for this
        //     item with expiry STRICTLY OLDER than the incoming line, push
        //     the incoming line to HighBay. Rationale: the older HighBay
        //     batch must reach Main first via the decant process; putting
        //     the fresher incoming into Main now would leave the older lot
        //     to expire in HighBay. This trumps the Min-Qty bypass below —
        //     Main can stay below Min until the older HighBay stock catches
        //     up via decant.
        //     QUANTITY-AWARE: the older HighBay lot only justifies diverting the
        //     WHOLE incoming line if it can actually cover what Main still needs.
        //     Where HighBay holds 60 older units but Main is 200 short, sending
        //     everything to HighBay leaves the pick face 140 short until a second
        //     decant cycle. So when HighBay's older qty falls short, the line is
        //     allowed through to the decant face and capped at the NET shortfall
        //     (shortfall − HighBay older qty) — HandleBinCapacity then splits the
        //     remainder off to HighBay, preserving room for the older lot to land.
        EarliestHighBayExpiry := GetEarliestHighBayExpiry(WhseActivityLine."Item No.");
        if (EarliestHighBayExpiry <> 0D) and (EarliestHighBayExpiry < WhseActivityLine."Expiration Date") then begin
            MainShortfall := GetMainMinQtyShortfall(WhseActivityLine."Item No.", TargetType);
            HighBayOlderQty := GetHighBayOlderQty(WhseActivityLine."Item No.", WhseActivityLine."Expiration Date");
            NetShortfall := MainShortfall - HighBayOlderQty;

            if NetShortfall <= 0 then begin
                // Older HighBay stock covers Main's need — original behaviour.
                AssignTargetBin(WhseActivityLine, TargetType::HighBay);
                OnAfterRoutePutAwayLine(WhseActivityLine);
                exit;
            end;

            // Older stock is not enough — top the face up with this line, capped
            // at the net shortfall by HandleBinCapacity via G_NetShortfallCap.
            G_NetShortfallCap := NetShortfall;
            G_NetShortfallScopeKey := ScopeKey;
            AssignTargetBin(WhseActivityLine, TargetType);
            OnAfterRoutePutAwayLine(WhseActivityLine);
            exit;
        end;

        // 3. Min-Qty top-up bypass (applies to all target types):
        //    If on-hand qty for the item in the target decant bin (Main + Receive)
        //    is below the Main-WH bin's Min Qty, skip the expiry check and route
        //    everything to the target — the Max-Qty cap in HandleBinCapacity
        //    will still split overflow to HighBay. The decant face must stay
        //    above Min Qty even at the cost of holding fresher stock with older.
        if IsTargetBinBelowMinQty(WhseActivityLine."Item No.", TargetType) then begin
            AssignTargetBin(WhseActivityLine, TargetType);
            OnAfterRoutePutAwayLine(WhseActivityLine);
            exit;
        end;

        // 4. Otherwise compare expiry against the latest expiry already in the target bin.
        LastDecantExpiry := GetLatestDecantExpiry(WhseActivityLine."Item No.", TargetType);

        if (LastDecantExpiry = 0D) or (WhseActivityLine."Expiration Date" <= LastDecantExpiry) then
            AssignTargetBin(WhseActivityLine, TargetType)
        else
            // Incoming stock is fresher than what's on the decant face — push to HighBay.
            AssignTargetBin(WhseActivityLine, TargetType::HighBay);

        OnAfterRoutePutAwayLine(WhseActivityLine);
    end;

    /// <summary>
    /// TRUE when the item's target decant face is below Min Qty in Main WH.
    /// Drives the "top up regardless of expiry" rule. HighBay is not a decant
    /// face and is excluded.
    ///
    /// Per zone:
    ///   - BulkDecant: one dedicated bin per BULK item. Check that bin's
    ///     OnHand + Receive-side in-flight qty against its Min Qty.
    ///   - Flowrack / Static: an item can have Bin Content rows on MULTIPLE
    ///     flagged bins in Main. The bypass fires if ANY of those bins is
    ///     individually below its own Min Qty (so a depleted Flowrack face
    ///     can be topped up even if the first bin alphabetically is full).
    ///     Receive-side in-flight qty is NOT added per Main bin — it's a
    ///     shared funnel, not yet allocated to a specific Main pick face.
    /// </summary>
    local procedure IsTargetBinBelowMinQty(ItemNo: Code[20]; TargetType: Enum "Put-Away Target Zone NDPP"): Boolean
    var
        MainBinContent: Record "Bin Content";
        ReceiveBinContent: Record "Bin Content";
        Bin: Record Bin;
        MainLocation: Code[20];
        AvailableBaseQty: Decimal;
        MinBaseQty: Decimal;
    begin
        // HighBay is not a decant face — no Min Qty bypass concept.
        if TargetType = TargetType::HighBay then
            exit(false);

        MainLocation := G_KamWhseSetupLookup.GetMainLocation();

        // Flowrack / Static branch.
        //
        // Step A (aggregate gate): sum every flagged Main bin's Quantity and
        // Min Qty, and add Receive-side pipeline qty (posted + pending) for
        // the routing type. If aggregate qty already meets aggregate Min, no
        // bin needs topping up — the pipeline will satisfy them via decant.
        // Bypass is suppressed; line falls through to the expiry check.
        //
        // Step B (per-bin rotation): if the pipeline is NOT enough, walk
        // flagged Main bins. Skip any already CLAIMED by an earlier line in
        // this batch (so successive lines don't keep targeting the same Main
        // bin's capacity). On the first unclaimed below-Min bin: claim it
        // and return TRUE. Returns FALSE when no remaining Main bin qualifies.
        if TargetType in [TargetType::Flowrack, TargetType::"Static"] then begin
            Bin.SetRange("Location Code", MainLocation);
            case TargetType of
                TargetType::Flowrack:
                    Bin.SetRange(Flowrack, true);
                TargetType::"Static":
                    Bin.SetRange("Static", true);
            end;
            if not Bin.FindSet() then
                exit(false);

            // Step A: aggregate pre-check.
            AvailableBaseQty := 0;
            MinBaseQty := 0;
            repeat
                MainBinContent.Reset();
                MainBinContent.SetRange("Location Code", MainLocation);
                MainBinContent.SetRange("Bin Code", Bin.Code);
                MainBinContent.SetRange("Item No.", ItemNo);
                if MainBinContent.FindFirst() then begin
                    MainBinContent.CalcFields("Quantity (Base)");
                    AvailableBaseQty += MainBinContent."Quantity (Base)";
                    MinBaseQty += MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
                end;
            until Bin.Next() = 0;

            AvailableBaseQty += GetReceivePipelineQty(ItemNo, TargetType);
            if (MinBaseQty > 0) and (AvailableBaseQty >= MinBaseQty) then
                exit(false); // Pipeline meets aggregate Min — no bypass needed.

            // Step B: per-bin rotation walk.
            Bin.Reset();
            Bin.SetRange("Location Code", MainLocation);
            case TargetType of
                TargetType::Flowrack:
                    Bin.SetRange(Flowrack, true);
                TargetType::"Static":
                    Bin.SetRange("Static", true);
            end;
            if Bin.FindSet() then
                repeat
                    if not IsBinClaimedThisBatch(ItemNo, Bin.Code) then begin
                        MainBinContent.Reset();
                        MainBinContent.SetRange("Location Code", MainLocation);
                        MainBinContent.SetRange("Bin Code", Bin.Code);
                        MainBinContent.SetRange("Item No.", ItemNo);
                        if MainBinContent.FindFirst() then begin
                            MinBaseQty := MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
                            if MinBaseQty > 0 then begin
                                MainBinContent.CalcFields("Quantity (Base)");
                                if MainBinContent."Quantity (Base)" < MinBaseQty then begin
                                    MarkBinClaimedThisBatch(ItemNo, Bin.Code);
                                    exit(true);
                                end;
                            end;
                        end;
                    end;
                until Bin.Next() = 0;
            exit(false);
        end;

        // BulkDecant: existing single-bin-per-item path, including Receive-side
        // in-flight qty (Receive's per-item BULK bin).
        if not TryGetMainBinContent(ItemNo, TargetType, MainBinContent) then
            exit(false); // No Main WH bin / no setup — can't evaluate, skip the bypass.

        MinBaseQty := MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
        if MinBaseQty <= 0 then
            exit(false); // No Min Qty configured — bypass disabled for this item.

        MainBinContent.CalcFields("Quantity (Base)");
        AvailableBaseQty := MainBinContent."Quantity (Base)" + GetReceivePipelineQty(ItemNo, TargetType);

        exit(AvailableBaseQty < MinBaseQty);
    end;

    /// <summary>
    /// Returns Main's total replenishment SHORTFALL (base) for the item — "how
    /// much does the decant face still need to fill every qualifying bin".
    ///
    /// Min triggers, Max targets: a bin counts only once its on-hand has fallen
    /// BELOW its own Min Qty (the same gate SumMainWHEmptyTotes applies), and it
    /// is then measured up to its Max Qty. See GetBinFillTarget.
    ///
    /// Deliberately summed PER BIN rather than on the aggregates: an overstocked
    /// bin must not mask a starved sibling. With 4 Flowrack bins at Min 100 /
    /// Max 500 where one holds 900 and three hold 0, the aggregate view sees
    /// 900 >= 400 and reports no need; the per-bin view correctly reports 1500
    /// (three empty bins, each filled to Max).
    ///
    /// Receive-side pipeline qty (posted + pending at the Receive decant bin)
    /// is netted off the total, since that stock is already on its way to Main.
    ///
    /// Returns 0 for HighBay (not a decant face) and when no Min Qty is set up.
    /// </summary>
    /// <summary>
    /// The base qty a qualifying bin should be filled UP TO — its Max Qty when
    /// one is configured, otherwise its Min Qty.
    ///
    /// Min and Max play different roles here: Min decides WHETHER a bin takes
    /// stock (the trigger gate, applied by the caller and mirrored in
    /// SumMainWHEmptyTotes), Max decides HOW MUCH once it does. Filling only to
    /// Min would leave the face sitting on the threshold and re-trigger
    /// replenishment on the next pick.
    ///
    /// Falling back to Min when Max is 0 keeps bins with partial setup working
    /// exactly as they did before this rule existed, rather than silently
    /// contributing nothing.
    /// </summary>
    local procedure GetBinFillTarget(var MainBinContent: Record "Bin Content"; MinBaseQty: Decimal): Decimal
    var
        MaxBaseQty: Decimal;
    begin
        MaxBaseQty := MainBinContent."Max. Qty." * MainBinContent."Qty. per Unit of Measure";
        if MaxBaseQty > MinBaseQty then
            exit(MaxBaseQty);
        exit(MinBaseQty);
    end;

    local procedure GetMainMinQtyShortfall(ItemNo: Code[20]; TargetType: Enum "Put-Away Target Zone NDPP"): Decimal
    var
        Bin: Record Bin;
        MainBinContent: Record "Bin Content";
        MainLocation: Code[20];
        MinBaseQty: Decimal;
        BinShortfall: Decimal;
        TotalShortfall: Decimal;
    begin
        if TargetType = TargetType::HighBay then
            exit(0);

        MainLocation := G_KamWhseSetupLookup.GetMainLocation();

        // Flowrack / Static: walk every flagged Main bin and sum the per-bin gap.
        if TargetType in [TargetType::Flowrack, TargetType::"Static"] then begin
            Bin.SetRange("Location Code", MainLocation);
            case TargetType of
                TargetType::Flowrack:
                    Bin.SetRange(Flowrack, true);
                TargetType::"Static":
                    Bin.SetRange("Static", true);
            end;
            if not Bin.FindSet() then
                exit(0);

            repeat
                MainBinContent.Reset();
                MainBinContent.SetRange("Location Code", MainLocation);
                MainBinContent.SetRange("Bin Code", Bin.Code);
                MainBinContent.SetRange("Item No.", ItemNo);
                if MainBinContent.FindFirst() then begin
                    MinBaseQty := MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
                    if MinBaseQty > 0 then begin
                        MainBinContent.CalcFields("Quantity (Base)");
                        // Min is the TRIGGER, Max is the TARGET: a bin only takes
                        // stock once it has dropped below Min (same gate as
                        // SumMainWHEmptyTotes), but once it qualifies it is filled
                        // all the way to Max — topping up only to Min would leave
                        // the face barely above the threshold and re-trigger
                        // replenishment on the next pick.
                        if MainBinContent."Quantity (Base)" < MinBaseQty then begin
                            BinShortfall := GetBinFillTarget(MainBinContent, MinBaseQty)
                                            - MainBinContent."Quantity (Base)";
                            if BinShortfall > 0 then
                                TotalShortfall += BinShortfall;
                        end;
                    end;
                end;
            until Bin.Next() = 0;
        end else begin
            // BulkDecant: single Main bin per item. Same Min-trigger /
            // Max-target rule as the Flowrack / Static branch above.
            if not TryGetMainBinContent(ItemNo, TargetType, MainBinContent) then
                exit(0);
            MinBaseQty := MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
            if MinBaseQty <= 0 then
                exit(0);
            MainBinContent.CalcFields("Quantity (Base)");
            if MainBinContent."Quantity (Base)" < MinBaseQty then
                TotalShortfall := GetBinFillTarget(MainBinContent, MinBaseQty)
                                  - MainBinContent."Quantity (Base)";
        end;

        if TotalShortfall <= 0 then
            exit(0);

        // Stock already staged / in-flight at Receive counts against the need.
        TotalShortfall -= GetReceivePipelineQty(ItemNo, TargetType);
        if TotalShortfall < 0 then
            exit(0);

        exit(TotalShortfall);
    end;

    /// <summary>
    /// After the Put-Away line is inserted, check whether it would exceed the
    /// Main-WH equivalent bin's Max Qty. If so, split it and send the overflow
    /// to HighBay.
    /// </summary>
    procedure HandleBinCapacity(var WhseActivityLine: Record "Warehouse Activity Line")
    var
        SplitLine: Record "Warehouse Activity Line";
        IsHandled: Boolean;
        SpaceLeftInDecant: Decimal;
    begin
        OnBeforeHandleBinCapacity(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        // Defensive: don't trust prior state for the SplitLine signal.
        G_LineSpacing := false;

        // Only relevant if the line is currently sitting in a Decant bin (Bulk / Static / Flowrack).
        if IsLineInHighBay(WhseActivityLine) then
            exit;
        if not IsLineInDecantBin(WhseActivityLine) then
            exit;

        // Capacity behind the staging bin this line currently targets — summed
        // across every routing type staging there (GEN DECANT covers both the
        // Static Max-Qty space and the Flowrack tote space).
        SpaceLeftInDecant := ResolveSpaceLeftForStaging(WhseActivityLine, GetLineStagingType(WhseActivityLine));

        // Net-shortfall cap (set by the HighBay older-stock guard in
        // RoutePutAwayLine when HighBay's older lot could NOT cover Main's need).
        // Only ever TIGHTENS the space: the face takes just enough to close the
        // gap the older lot leaves, so that older lot still has room to land on
        // its own decant cycle. The cap is consumed across the lines of this
        // (Doc No. | Item No.) scope — each line draws down what it uses.
        if (G_NetShortfallCap > 0) and (G_NetShortfallScopeKey = WhseActivityLine."No." + '|' + WhseActivityLine."Item No.") then
            if SpaceLeftInDecant > G_NetShortfallCap then
                SpaceLeftInDecant := G_NetShortfallCap;

        // This staging bin is full — hand the whole line to the next staging bin
        // in fill order, or to High Bay when none is left. Previously this went
        // straight to High Bay, stranding stock there while a valid pick face
        // of the item's OTHER routing type stood empty.
        if SpaceLeftInDecant <= 0 then begin
            AssignTargetBin(WhseActivityLine, GetNextStagingType(WhseActivityLine));
            WhseActivityLine.Modify();
            exit;
        end;

        // Decant bin can absorb the whole line — leave alone.
        if WhseActivityLine."Qty. (Base)" <= SpaceLeftInDecant then begin
            ConsumeNetShortfallCap(WhseActivityLine, WhseActivityLine."Qty. (Base)");
            exit;
        end;

        // Split: keep `SpaceLeftInDecant` here, and let the spillover line be
        // routed onward by OnBeforeInsertNewWhseActivLine -> RouteSplitLine,
        // which cascades it to the next staging bin (and so on, until the
        // remainder lands in High Bay).
        ConsumeNetShortfallCap(WhseActivityLine, SpaceLeftInDecant);
        WhseActivityLine.Validate("Qty. to Handle (Base)", SpaceLeftInDecant);
        WhseActivityLine.Modify();

        G_SplitFromStagingType := GetLineStagingType(WhseActivityLine);
        G_SplitFromItemNo := WhseActivityLine."Item No.";

        SplitLine.Copy(WhseActivityLine);
        G_LineSpacing := true;
        WhseActivityLine.SplitLine(SplitLine);
        WhseActivityLine.Copy(SplitLine);
        G_LineSpacing := false;

        Clear(G_SplitFromStagingType);
        G_SplitFromItemNo := '';

        OnAfterHandleBinCapacity(WhseActivityLine);
    end;

    /// <summary>
    /// The staging bin type the line currently sits in, inferred from its Bin's
    /// routing flags. BULK DECANT and GEN DECANT are distinct staging bins;
    /// Static and Flowrack both resolve to GEN DECANT (the Receive
    /// Flowrack-flagged bin), matching RoutingTypeToStagingType.
    /// </summary>
    local procedure GetLineStagingType(var WhseActivityLine: Record "Warehouse Activity Line"): Enum "Put-Away Target Zone NDPP"
    var
        Bin: Record Bin;
        TargetType: Enum "Put-Away Target Zone NDPP";
    begin
        if not Bin.Get(WhseActivityLine."Location Code", WhseActivityLine."Bin Code") then
            exit(TargetType::HighBay);
        if Bin.HighBay then
            exit(TargetType::HighBay);
        if Bin.Bulk then
            exit(TargetType::BulkDecant);
        // Receive's GEN DECANT bin carries the Flowrack flag (and may also carry
        // Static — the two share it).
        exit(TargetType::Flowrack);
    end;

    /// <summary>
    /// The staging bin AFTER the one the line currently targets, in the item's
    /// fill order. High Bay when the current bin is the item's last — so the
    /// remainder always has somewhere to land.
    /// </summary>
    local procedure GetNextStagingType(var WhseActivityLine: Record "Warehouse Activity Line"): Enum "Put-Away Target Zone NDPP"
    begin
        exit(GetStagingTypeAfter(WhseActivityLine."Item No.", GetLineStagingType(WhseActivityLine)));
    end;

    local procedure GetStagingTypeAfter(ItemNo: Code[20]; CurrentStagingType: Enum "Put-Away Target Zone NDPP"): Enum "Put-Away Target Zone NDPP"
    var
        StagingTypes: List of [Enum "Put-Away Target Zone NDPP"];
        TargetType: Enum "Put-Away Target Zone NDPP";
        Idx: Integer;
    begin
        StagingTypes := GetStagingTypesForItem(ItemNo);
        if not StagingTypes.Contains(CurrentStagingType) then
            exit(TargetType::HighBay);

        Idx := StagingTypes.IndexOf(CurrentStagingType);
        if Idx >= StagingTypes.Count() then
            exit(TargetType::HighBay); // Already the item's last staging bin.

        exit(StagingTypes.Get(Idx + 1));
    end;

    /// <summary>
    /// Routes a line created by SplitLine() inside HandleBinCapacity. The
    /// spillover goes to the staging bin after the one it split from; when that
    /// bin is also full, this line's own HandleBinCapacity pass splits it again,
    /// cascading until the remainder reaches High Bay.
    ///
    /// Falls back to High Bay whenever the split context is absent (a split from
    /// some other flow) or the item doesn't match — never leaves a line
    /// unrouted.
    /// </summary>
    procedure RouteSplitLine(var WhseActivityLine: Record "Warehouse Activity Line")
    var
        TargetType: Enum "Put-Away Target Zone NDPP";
    begin
        if (G_SplitFromItemNo <> '') and (G_SplitFromItemNo = WhseActivityLine."Item No.") then
            AssignTargetBin(WhseActivityLine, GetStagingTypeAfter(WhseActivityLine."Item No.", G_SplitFromStagingType))
        else
            AssignTargetBin(WhseActivityLine, TargetType::HighBay);
    end;

    /// <summary>
    /// Draws UsedQty down from the active net-shortfall cap once a line has
    /// taken its share of the decant face. Without this, every line of a
    /// multi-line receipt for the same item would be granted the full cap and
    /// the face would be oversubscribed. No-op when no cap is active or the
    /// line belongs to a different (Doc No. | Item No.) scope.
    /// </summary>
    local procedure ConsumeNetShortfallCap(var WhseActivityLine: Record "Warehouse Activity Line"; UsedQty: Decimal)
    begin
        if G_NetShortfallCap <= 0 then
            exit;
        if G_NetShortfallScopeKey <> WhseActivityLine."No." + '|' + WhseActivityLine."Item No." then
            exit;

        G_NetShortfallCap -= UsedQty;
        if G_NetShortfallCap < 0 then
            G_NetShortfallCap := 0;
    end;

    /// <summary>
    /// Provides the line spacing for split lines — keeps split lines visually
    /// adjacent in the activity (5000 leaves room for further splits).
    /// </summary>
    procedure GetSplitLineSpacing(): Integer
    begin
        if G_LineSpacing then
            exit(5000);
        exit(0);
    end;

    /// <summary>
    /// Returns TRUE only for Put-Away Place lines from a Purchase Order
    /// at the Receive Location — the only context US 40488 cares about.
    /// </summary>
    local procedure IsEligibleForRouting(var WhseActivityLine: Record "Warehouse Activity Line"): Boolean
    begin
        if WhseActivityLine."Location Code" <> G_KamWhseSetupLookup.GetReceiveLocation() then
            exit(false);
        if WhseActivityLine."Activity Type" <> WhseActivityLine."Activity Type"::"Put-away" then
            exit(false);
        if WhseActivityLine."Action Type" <> WhseActivityLine."Action Type"::Place then
            exit(false);
        if WhseActivityLine."Source Document" <> WhseActivityLine."Source Document"::"Purchase Order" then
            exit(false);
        exit(true);
    end;

    /// <summary>
    /// Maps Item routing type to the put-away target bin type.
    ///
    /// NOTE: At put-away, BOTH Static and Flowrack items land in the GEN DECANT
    /// (Flowrack) bin. The Static-vs-Flowrack distinction only matters during
    /// the decant phase, where they have different capacity rules. Put-away
    /// just uses the Main-WH GEN DECANT bin's Max Qty for both.
    /// </summary>
    local procedure RoutingTypeToTargetType(RoutingType: Enum "Item Routing Type NDPP"): Enum "Put-Away Target Zone NDPP"
    var
        TargetType: Enum "Put-Away Target Zone NDPP";
    begin
        case RoutingType of
            RoutingType::BULK:
                exit(TargetType::BulkDecant);
            RoutingType::"Static":
                exit(TargetType::"Static");
            else
                // Flowrack (and any future non-BULK / non-Static routing).
                exit(TargetType::Flowrack);
        end;
    end;

    /// <summary>
    /// The item's routing types, in the configured fill order, restricted to
    /// those with Bin Content in Main WH. Empty means "no routing bins set up"
    /// — the caller routes the line to High Bay.
    ///
    /// Replaces the former single-valued Item."Routing Type": an item may be
    /// BULK and Flowrack at once, and both faces must be considered.
    /// </summary>
    local procedure GetRoutingTypesForLine(ItemNo: Code[20]): List of [Enum "Item Routing Type NDPP"]
    begin
        exit(G_KamWhseSetupLookup.GetItemRoutingTypes(ItemNo));
    end;

    /// <summary>
    /// The Receive-side staging bin an item's routing type puts away to.
    ///
    /// Static and Flowrack SHARE the GEN DECANT (Flowrack-flagged) bin at
    /// Receive — the Static-vs-Flowrack split is resolved later, during decant.
    /// So a dual Static+Flowrack item yields ONE Place line, whose capacity is
    /// the SUM of its Static Max-Qty space and its Flowrack tote space (see
    /// ResolveSpaceLeftForTypes). Only BULK has its own separate staging bin.
    /// </summary>
    local procedure RoutingTypeToStagingType(RoutingType: Enum "Item Routing Type NDPP"): Enum "Put-Away Target Zone NDPP"
    var
        TargetType: Enum "Put-Away Target Zone NDPP";
    begin
        if RoutingType = RoutingType::BULK then
            exit(TargetType::BulkDecant);
        // Static and Flowrack both stage at the Receive Flowrack bin (GEN DECANT).
        exit(TargetType::Flowrack);
    end;

    /// <summary>
    /// The Receive staging bins the item puts away to, in fill order.
    /// A BULK+Static+Flowrack item yields two: BULK DECANT, then GEN DECANT
    /// (Static and Flowrack share it). Each becomes at most one Place line.
    /// </summary>
    local procedure GetStagingTypesForItem(ItemNo: Code[20]): List of [Enum "Put-Away Target Zone NDPP"]
    var
        RoutingType: Enum "Item Routing Type NDPP";
        StagingType: Enum "Put-Away Target Zone NDPP";
        Result: List of [Enum "Put-Away Target Zone NDPP"];
    begin
        foreach RoutingType in GetRoutingTypesForLine(ItemNo) do begin
            StagingType := RoutingTypeToStagingType(RoutingType);
            if not Result.Contains(StagingType) then
                Result.Add(StagingType);
        end;
        exit(Result);
    end;

    /// <summary>
    /// Total capacity behind a Receive staging bin for this item, summed across
    /// every routing type that stages there AND that the item actually has.
    ///
    /// GEN DECANT feeds both the Static and Flowrack Main faces, and their
    /// capacity rules differ — Static by Max Qty, Flowrack by empty totes ×
    /// qty-per-tote. For a dual Static+Flowrack item both faces genuinely have
    /// room, so the staging line's capacity is their SUM. The old code took the
    /// Static branch alone and never saw the Flowrack totes, sending stock to
    /// High Bay while a valid pick face stood empty.
    /// </summary>
    local procedure ResolveSpaceLeftForStaging(var WhseActivityLine: Record "Warehouse Activity Line"; StagingType: Enum "Put-Away Target Zone NDPP"): Decimal
    var
        RoutingType: Enum "Item Routing Type NDPP";
        Total: Decimal;
    begin
        foreach RoutingType in GetRoutingTypesForLine(WhseActivityLine."Item No.") do
            if RoutingTypeToStagingType(RoutingType) = StagingType then
                Total += ResolveSpaceLeftForRoutingType(WhseActivityLine, RoutingType);
        exit(Total);
    end;

    /// <summary>
    /// Returns the base-qty SPACE LEFT in the put-away target bin.
    ///
    ///   Static    -> Step 1: try Max Qty rule
    ///                        Sum (MaxQty × QtyPerUoM − on-hand) across all
    ///                        Main WH Static bins that hold the item. Net out
    ///                        sibling pending qty at the Receive Flowrack bin,
    ///                        add back current line's own contribution.
    ///                  Step 2: if Max Qty sums to 0 (none configured),
    ///                        fall through to the Flowrack empty-totes rule.
    ///
    ///   Flowrack  -> SumMainWHEmptyTotes(item, Flowrack) × QtyPerTote
    ///                Empty totes summed across Main WH Flowrack bins.
    ///                CountPendingFlowrackTotes nets earlier batch lines that
    ///                already claimed totes.
    ///
    ///   BULK      -> (Max Qty × Qty per UoM)
    ///                − CalcReservedQty(...)
    ///                + (current line's qty if it targets this zone)
    ///                Single Main WH BULK bin per item. Adding current-line
    ///                back gives "space BEFORE this line" since Bin Content
    ///                already counts it post-insert.
    ///
    /// Returns 0 when there's no room. For Flowrack/Static fall-through, a
    /// missing tote setup (no QtyPerTote / no Number-of-Totes in Main WH bins)
    /// yields 0 → entire line to HighBay.
    /// </summary>



    local procedure ResolveSpaceLeftForRoutingType(var WhseActivityLine: Record "Warehouse Activity Line"; RoutingType: Enum "Item Routing Type NDPP"): Decimal
    var
        MainBinContent: Record "Bin Content";
        TargetType: Enum "Put-Away Target Zone NDPP";
        QtyPerTote: Decimal;
        BinMaxBaseQty: Decimal;
        MaxQtySpace: Decimal;
        EmptyTotes: Integer;
    begin
        // Static: try Max Qty rule first (summed across all Main WH Static bins).
        // If no Max Qty is configured anywhere, fall through to empty-totes.
        if RoutingType = RoutingType::"Static" then begin
            MaxQtySpace := SumMainWHMaxQtySpaceLeft(WhseActivityLine."Item No.", RoutingType);
            if MaxQtySpace > 0 then begin
                MaxQtySpace := MaxQtySpace
                               - GetReceiveDecantPendingForItem(WhseActivityLine."Item No.", RoutingType)
                               + GetCurrentLineSelfContribution(WhseActivityLine, "Put-Away Target Zone NDPP"::"Static");
                if MaxQtySpace < 0 then
                    MaxQtySpace := 0;
                exit(MaxQtySpace);
            end;
        end;

        if RoutingType = RoutingType::Flowrack then begin
            QtyPerTote := KamToteMath.GetQtyPerTote(WhseActivityLine."Item No.", WhseActivityLine."Manufacturer Code");
            if QtyPerTote <= 0 then
                exit(0);

            EmptyTotes := SumMainWHEmptyTotes(WhseActivityLine."Item No.", RoutingType)
                          - CountPendingFlowrackTotes(WhseActivityLine)
                          - CountReceiveFlowrackTotes(WhseActivityLine."Item No.");
            if EmptyTotes < 0 then
                EmptyTotes := 0;
            exit(EmptyTotes * QtyPerTote);
        end;

        // BULK — Max Qty rule against the single Main WH BULK bin.
        TargetType := RoutingTypeToTargetType(RoutingType);
        if not TryGetMainBinContent(WhseActivityLine."Item No.", TargetType, MainBinContent) then
            exit(0);

        BinMaxBaseQty := MainBinContent."Max. Qty." * MainBinContent."Qty. per Unit of Measure";
        if BinMaxBaseQty <= 0 then
            exit(0);

        exit(BinMaxBaseQty
             - CalcReservedQty(WhseActivityLine."Item No.", TargetType)
             + GetCurrentLineSelfContribution(WhseActivityLine, TargetType));
    end;

    /// <summary>
    /// Sums empty totes across every Main-WH bin flagged for the item's routing
    /// type (Flowrack or Static). For each matching bin: empty = "Number of
    /// Totes in a Bin" - totes currently filled (per posted Warehouse Entries).
    /// Bins without a Bin Content row for this item contribute 0.
    /// Returns 0 for any other routing type (BULK uses Max Qty, not totes).
    /// </summary>
    /// <summary>
    /// Sums (Max Qty x Qty per UoM) − (on-hand qty) across every Main-WH bin
    /// flagged for the item's routing type that has a Bin Content row for the
    /// item. Bins without Max Qty configured (or already at/over capacity)
    /// contribute 0. Used by the Static Max-Qty rule.
    /// </summary>
    local procedure SumMainWHMaxQtySpaceLeft(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Decimal
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
        MainLocation: Code[20];
        MaxQtyBase: Decimal;
        OnHand: Decimal;
        BinSpace: Decimal;
        Total: Decimal;
    begin
        MainLocation := G_KamWhseSetupLookup.GetMainLocation();
        Bin.SetRange("Location Code", MainLocation);
        case RoutingType of
            RoutingType::BULK:
                Bin.SetRange(Bulk, true);
            RoutingType::Flowrack:
                Bin.SetRange(Flowrack, true);
            RoutingType::"Static":
                Bin.SetRange("Static", true);
            else
                exit(0);
        end;
        if not Bin.FindSet() then
            exit(0);

        repeat
            BinContent.Reset();
            BinContent.SetRange("Location Code", MainLocation);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if BinContent.FindFirst() then begin
                MaxQtyBase := BinContent."Max. Qty." * BinContent."Qty. per Unit of Measure";
                if MaxQtyBase > 0 then begin
                    BinContent.CalcFields("Quantity (Base)", "Put-away Quantity (Base)", "Positive Adjmt. Qty. (Base)");
                    OnHand := BinContent."Quantity (Base)"
                              + BinContent."Put-away Quantity (Base)"
                              + BinContent."Positive Adjmt. Qty. (Base)";
                    BinSpace := MaxQtyBase - OnHand;
                    if BinSpace > 0 then
                        Total += BinSpace;
                end;
            end;
        until Bin.Next() = 0;

        exit(Total);
    end;

    /// <summary>
    /// Sums pending Put-away Place qty at the Receive-side bin flagged for the
    /// given RoutingType (Flowrack or Static) for this item, INCLUDING the
    /// current in-flight line. RoutingType picks which Receive bin to read —
    /// Static items pull from the Static bin, Flowrack items from the
    /// Flowrack bin. Returns 0 for any other type.
    ///
    /// Why query Warehouse Activity Line directly rather than read
    /// Bin Content's "Put-away Quantity (Base)" FlowField: the FlowField
    /// only evaluates against an existing Bin Content row. For an item that
    /// has never had stock at the Receive bin (first-ever put-away of that
    /// item there), no Bin Content row exists → the FlowField yields 0 →
    /// Max-Qty math silently over-allocates capacity. A direct CalcSums on
    /// the activity line works whether or not a Bin Content row exists.
    /// </summary>
    local procedure GetReceiveDecantPendingForItem(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Decimal
    var
        Bin: Record Bin;
        WhseActLine: Record "Warehouse Activity Line";
        ReceiveLocation: Code[20];
        ReceiveBinCode: Code[20];
    begin
        ReceiveLocation := G_KamWhseSetupLookup.GetReceiveLocation();
        case RoutingType of
            RoutingType::Flowrack:
                begin
                    Bin.SetRange("Location Code", ReceiveLocation);
                    Bin.SetRange(Flowrack, true);
                    if not Bin.FindFirst() then
                        exit(0);
                    ReceiveBinCode := Bin.Code;
                end;
            RoutingType::"Static":
                begin
                    Bin.SetRange("Location Code", ReceiveLocation);
                    Bin.SetRange("Static", true);
                    if not Bin.FindFirst() then
                        exit(0);
                    ReceiveBinCode := Bin.Code;
                end;
            RoutingType::BULK:
                // BULK is item-specific: one BULK bin per item per location.
                ReceiveBinCode := GetItemBulkBinCode(ReceiveLocation, ItemNo);
            else
                exit(0);
        end;
        if ReceiveBinCode = '' then
            exit(0);

        WhseActLine.SetCurrentKey("Item No.", "Location Code");
        WhseActLine.SetRange("Item No.", ItemNo);
        WhseActLine.SetRange("Location Code", ReceiveLocation);
        WhseActLine.SetRange("Bin Code", ReceiveBinCode);
        WhseActLine.SetRange("Activity Type", WhseActLine."Activity Type"::"Put-away");
        WhseActLine.SetRange("Action Type", WhseActLine."Action Type"::Place);
        WhseActLine.CalcSums("Qty. Outstanding (Base)");
        exit(WhseActLine."Qty. Outstanding (Base)");
    end;

    // Vestigial Bin Content branch — kept temporarily, will remove once we
    // confirm the activity-line path above behaves correctly in production.
    local procedure GetReceiveDecantPendingForItem_BinContentImpl(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Decimal
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
        ReceiveLocation: Code[20];
        Total: Decimal;
    begin
        ReceiveLocation := G_KamWhseSetupLookup.GetReceiveLocation();
        Bin.SetRange("Location Code", ReceiveLocation);
        case RoutingType of
            RoutingType::Flowrack:
                Bin.SetRange(Flowrack, true);
            RoutingType::"Static":
                Bin.SetRange("Static", true);
            else
                exit(0);
        end;
        if not Bin.FindFirst() then
            exit(0);

        BinContent.SetRange("Location Code", ReceiveLocation);
        BinContent.SetRange("Bin Code", Bin.Code);
        BinContent.SetRange("Item No.", ItemNo);
        if BinContent.FindSet() then
            repeat
                BinContent.CalcFields("Quantity (Base)", "Put-away Quantity (Base)", "Positive Adjmt. Qty. (Base)");
                Total += BinContent."Quantity (Base)"
                         + BinContent."Put-away Quantity (Base)"
                         + BinContent."Positive Adjmt. Qty. (Base)";
            until BinContent.Next() = 0;
        exit(Total);
    end;

    local procedure SumMainWHEmptyTotes(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Integer
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
        TotalEmpty: Integer;
        BinEmpty: Integer;
        FilledTotes: Integer;
        TargetTotes: Integer;
        MinBaseQty: Decimal;
        MainLocation: Code[20];
    begin
        MainLocation := G_KamWhseSetupLookup.GetMainLocation();
        Bin.SetRange("Location Code", MainLocation);
        case RoutingType of
            RoutingType::Flowrack:
                Bin.SetRange(Flowrack, true);
            RoutingType::"Static":
                Bin.SetRange("Static", true);
            else
                exit(0);
        end;
        if not Bin.FindSet() then
            exit(0);

        repeat
            // Sum empty totes across every below-Min bin. The bin-claim mechanism
            // (G_TargetedBins) is intentionally NOT consulted here — cross-line
            // capacity dedup is done by CountPendingFlowrackTotes in
            // ResolveSpaceLeft, which subtracts the totes already consumed by
            // earlier lines in this batch. Skipping claimed bins here would
            // double-count that subtraction.
            BinContent.Reset();
            BinContent.SetRange("Location Code", MainLocation);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if BinContent.FindFirst() then begin
                // Only top up bins that actually need it — i.e. on-hand has dropped
                // below the bin's own Min Qty. Bins above Min Qty don't accept more
                // stock at put-away even if they have empty tote slots; that capacity
                // is reserved for future depletion cycles. Bins with no Min Qty
                // configured (0) are skipped — no threshold = no replenishment target.
                MinBaseQty := BinContent."Min. Qty." * BinContent."Qty. per Unit of Measure";
                if MinBaseQty > 0 then begin
                    BinContent.CalcFields("Quantity (Base)");
                    if BinContent."Quantity (Base)" < MinBaseQty then begin
                        TargetTotes := BinContent."Number of Totes in a Bin";
                        if TargetTotes > 0 then begin
                            FilledTotes := KamToteMath.CountTotesInFLOWRACKBin(BinContent);
                            BinEmpty := TargetTotes - FilledTotes;
                            if BinEmpty > 0 then
                                TotalEmpty += BinEmpty;
                        end;
                    end;
                end;
            end;
        until Bin.Next() = 0;

        exit(TotalEmpty);
    end;

    /// <summary>
    /// TRUE when the line currently points at the High Bay bin in its location.
    /// </summary>
    local procedure IsLineInHighBay(var WhseActivityLine: Record "Warehouse Activity Line"): Boolean
    var
        Bin: Record Bin;
    begin
        if WhseActivityLine."Bin Code" = '' then
            exit(false);
        if not Bin.Get(WhseActivityLine."Location Code", WhseActivityLine."Bin Code") then
            exit(false);
        exit(Bin.HighBay);
    end;

    /// <summary>
    /// TRUE when the line currently points at any Decant-style bin (Bulk / Static / Flowrack).
    /// </summary>
    local procedure IsLineInDecantBin(var WhseActivityLine: Record "Warehouse Activity Line"): Boolean
    var
        Bin: Record Bin;
    begin
        if WhseActivityLine."Bin Code" = '' then
            exit(false);
        if not Bin.Get(WhseActivityLine."Location Code", WhseActivityLine."Bin Code") then
            exit(false);
        exit(Bin.Bulk or Bin."Static" or Bin.Flowrack);
    end;

    /// <summary>
    /// Assigns the target Zone Code and Bin Code on a Put-Away line by finding
    /// the bin in this line's location flagged for the requested target type.
    /// </summary>
    local procedure AssignTargetBin(var WhseActivityLine: Record "Warehouse Activity Line"; TargetType: Enum "Put-Away Target Zone NDPP")
    var
        Bin: Record Bin;
        BulkBinCode: Code[20];
    begin
        // BULK is item-specific (multiple BULK bins per location possible, but
        // one bin per item). The master-data gate has already confirmed the
        // item has Bin Content somewhere — point the line at THAT bin.
        if TargetType = TargetType::BulkDecant then begin
            BulkBinCode := GetItemBulkBinCode(WhseActivityLine."Location Code", WhseActivityLine."Item No.");
            if BulkBinCode = '' then
                exit;
            if not Bin.Get(WhseActivityLine."Location Code", BulkBinCode) then
                exit;
            WhseActivityLine.Validate("Zone Code", Bin."Zone Code");
            WhseActivityLine.Validate("Bin Code", Bin.Code);
            exit;
        end;

        Bin.SetRange("Location Code", WhseActivityLine."Location Code");
        case TargetType of
            TargetType::"Static":
                Bin.SetRange("Static", true);
            TargetType::Flowrack:
                Bin.SetRange(Flowrack, true);
            TargetType::HighBay:
                Bin.SetRange(HighBay, true);
        end;
        if not Bin.FindFirst() then
            exit;

        WhseActivityLine.Validate("Zone Code", Bin."Zone Code");
        WhseActivityLine.Validate("Bin Code", Bin.Code);
    end;

    /// <summary>
    /// Returns total Receive-side "pipeline" qty for the item at the Receive
    /// bin flagged for the given TargetType — i.e. stock that will reach Main
    /// soon and should suppress the Min-Qty bypass.
    ///   Posted   — Warehouse Entry sum at the Receive bin (already received,
    ///              not yet decanted).
    ///   Pending  — Warehouse Activity Line Place lines targeted at the
    ///              Receive bin (current batch's put-aways not yet registered).
    /// BULK uses the item-specific BULK bin; Static / Flowrack use the
    /// routing-type-flagged shared bin. HighBay routes here as 0 (HighBay is
    /// not a decant pipeline).
    /// </summary>
    local procedure GetReceivePipelineQty(ItemNo: Code[20]; TargetType: Enum "Put-Away Target Zone NDPP"): Decimal
    var
        WhseEntry: Record "Warehouse Entry";
        WhseActLine: Record "Warehouse Activity Line";
        ReceiveLocation: Code[20];
        ReceiveBinCode: Code[20];
        Total: Decimal;
    begin
        ReceiveLocation := G_KamWhseSetupLookup.GetReceiveLocation();
        if TargetType = TargetType::BulkDecant then
            ReceiveBinCode := GetItemBulkBinCode(ReceiveLocation, ItemNo)
        else
            ReceiveBinCode := GetTargetBinCode(ReceiveLocation, TargetType);
        if ReceiveBinCode = '' then
            exit(0);

        WhseEntry.SetRange("Item No.", ItemNo);
        WhseEntry.SetRange("Location Code", ReceiveLocation);
        WhseEntry.SetRange("Bin Code", ReceiveBinCode);
        WhseEntry.CalcSums("Qty. (Base)");
        Total := WhseEntry."Qty. (Base)";

        WhseActLine.SetCurrentKey("Item No.", "Location Code");
        WhseActLine.SetRange("Item No.", ItemNo);
        WhseActLine.SetRange("Location Code", ReceiveLocation);
        WhseActLine.SetRange("Bin Code", ReceiveBinCode);
        WhseActLine.SetRange("Activity Type", WhseActLine."Activity Type"::"Put-away");
        WhseActLine.SetRange("Action Type", WhseActLine."Action Type"::Place);
        WhseActLine.CalcSums("Qty. Outstanding (Base)");
        Total += WhseActLine."Qty. Outstanding (Base)";

        exit(Total);
    end;

    /// <summary>
    /// The earliest Expiration Date that still counts as usable stock.
    /// Anything expiring STRICTLY BEFORE this date is expired and must not
    /// influence routing: it can never reach the pick face via decant, so
    /// treating it as FEFO pipeline holds capacity open for stock that will
    /// never fill it (US 40488 — expired HighBay lot starving Main).
    ///
    /// WorkDate (not Today) is the cutoff so backdated and test postings
    /// behave predictably — it is the date BC itself posts against.
    ///
    /// Callers apply it as a '>=' filter on Expiration Date.
    /// </summary>
    local procedure GetUsableExpiryCutoff(): Date
    begin
        exit(WorkDate());
    end;

    /// <summary>
    /// Returns the EARLIEST positive-qty, NON-EXPIRED Expiration Date in
    /// Receive HighBay for the item. Used by the HighBay-older-stock guard in
    /// RoutePutAwayLine: if HighBay already holds a lot older than the
    /// incoming line's expiry, the incoming line is pushed to HighBay so the
    /// older HighBay batch can reach Main first via decant (FEFO).
    /// Returns 0D when HighBay has no positive-qty stock for the item.
    /// </summary>
    local procedure GetEarliestHighBayExpiry(ItemNo: Code[20]): Date
    var
        WhseEntryQry: Query "Whse Entry Lot Det Asc NDPP";
        HighBayBin: Code[20];
        EarliestExpiry: Date;
    begin
        HighBayBin := GetItemHighbayBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), ItemNo);
        if HighBayBin = '' then
            exit(0D);

        WhseEntryQry.SetFilter(WhseEntryQry.Item_No_, '%1', ItemNo);
        WhseEntryQry.SetFilter(WhseEntryQry.Location_Code, '%1', G_KamWhseSetupLookup.GetReceiveLocation());
        WhseEntryQry.SetFilter(WhseEntryQry.Bin_Code, '%1', HighBayBin);
        WhseEntryQry.SetFilter(WhseEntryQry.Qty_Base, '>%1', 0);
        // Non-blank AND not already expired. Expired stock must not trip the
        // older-stock guard — it cannot reach Main via decant, so diverting
        // good incoming stock behind it starves the pick face indefinitely.
        WhseEntryQry.SetFilter(WhseEntryQry.Expiration_Date, '>=%1', GetUsableExpiryCutoff());
        WhseEntryQry.TopNumberOfRows(1);
        WhseEntryQry.Open();
        if WhseEntryQry.Read() then
            EarliestExpiry := WhseEntryQry.Expiration_Date;
        WhseEntryQry.Close();
        exit(EarliestExpiry);
    end;

    /// <summary>
    /// Returns the total positive HighBay qty (base) for the item whose
    /// Expiration Date is STRICTLY OLDER than IncomingExpiry but NOT YET
    /// EXPIRED — i.e. the stock genuinely queued ahead of the incoming line
    /// under FEFO, which will reach Main via decant before it.
    ///
    /// Companion to GetEarliestHighBayExpiry: that one answers "is there older
    /// stock?", this one answers "how much?". The older-stock guard in
    /// RoutePutAwayLine needs both — older stock only justifies diverting the
    /// whole incoming line if it is ALSO enough to cover Main's shortfall.
    ///
    /// Returns 0 when HighBay has no bin for the item or no older positive stock.
    /// </summary>
    local procedure GetHighBayOlderQty(ItemNo: Code[20]; IncomingExpiry: Date): Decimal
    var
        WhseEntryQry: Query "Whse Entry Lot Det Asc NDPP";
        HighBayBin: Code[20];
        TotalQty: Decimal;
    begin
        if IncomingExpiry = 0D then
            exit(0);

        HighBayBin := GetItemHighbayBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), ItemNo);
        if HighBayBin = '' then
            exit(0);

        WhseEntryQry.SetFilter(WhseEntryQry.Item_No_, '%1', ItemNo);
        WhseEntryQry.SetFilter(WhseEntryQry.Location_Code, '%1', G_KamWhseSetupLookup.GetReceiveLocation());
        WhseEntryQry.SetFilter(WhseEntryQry.Bin_Code, '%1', HighBayBin);
        WhseEntryQry.SetFilter(WhseEntryQry.Qty_Base, '>%1', 0);
        // Older than the incoming line, but still usable. Expired units cannot
        // cover Main's shortfall, so counting them here would cap the top-up
        // by a quantity that will never arrive.
        //
        // Both bounds go in ONE SetFilter: a second SetFilter on the same query
        // column REPLACES the first rather than intersecting with it, which
        // would silently drop the expiry floor.
        WhseEntryQry.SetFilter(WhseEntryQry.Expiration_Date, '%1..%2', GetUsableExpiryCutoff(), IncomingExpiry - 1);
        WhseEntryQry.Open();
        while WhseEntryQry.Read() do
            TotalQty += WhseEntryQry.Qty_Base;
        WhseEntryQry.Close();

        exit(TotalQty);
    end;

    /// <summary>
    /// Resets per-batch routing state. Called from the OnBeforeCode subscriber
    /// on cod 7313 at the start of every Create Put-away run so claims from a
    /// previous run don't leak into a new one.
    /// </summary>
    procedure ResetBatch()
    begin
        Clear(G_TargetedBins);
        G_NetShortfallCap := 0;
        G_NetShortfallScopeKey := '';
    end;

    local procedure IsBinClaimedThisBatch(ItemNo: Code[20]; BinCode: Code[20]): Boolean
    begin
        exit(G_TargetedBins.ContainsKey(BinClaimKey(ItemNo, BinCode)));
    end;

    local procedure MarkBinClaimedThisBatch(ItemNo: Code[20]; BinCode: Code[20])
    var
        L_Key: Text;
    begin
        L_Key := BinClaimKey(ItemNo, BinCode);
        if not G_TargetedBins.ContainsKey(L_Key) then
            G_TargetedBins.Add(L_Key, true);
    end;

    local procedure BinClaimKey(ItemNo: Code[20]; BinCode: Code[20]): Text
    begin
        exit(ItemNo + '|' + BinCode);
    end;

    /// <summary>
    /// Returns the LATEST Expiration Date currently held in the target bin's
    /// Zone for the given item (positive on-hand qty only).
    /// </summary>
    local procedure GetLatestDecantExpiry(ItemNo: Code[20]; TargetType: Enum "Put-Away Target Zone NDPP"): Date
    var
        WhseEntryQry: Query "Whse Entry Lot Details NDPP";
        BinCode: Code[20];
        LastExpiry: Date;
    begin
        // BULK: item-specific bin (multiple BULK bins per location possible).
        // if TargetType = TargetType::BulkDecant then
        //     BinCode := GetItemBulkBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), ItemNo)
        // else
        //     BinCode := GetTargetBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), TargetType);

        BinCode := GetItemHighbayBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), ItemNo);

        if BinCode = '' then
            exit(0D);

        WhseEntryQry.SetFilter(WhseEntryQry.Item_No_, '%1', ItemNo);
        WhseEntryQry.SetFilter(WhseEntryQry.Location_Code, '%1', G_KamWhseSetupLookup.GetReceiveLocation());
        WhseEntryQry.SetFilter(WhseEntryQry.Bin_Code, '%1', BinCode);
        WhseEntryQry.SetFilter(WhseEntryQry.Qty_Base, '>%1', 0);
        WhseEntryQry.TopNumberOfRows(1);
        WhseEntryQry.Open();
        if WhseEntryQry.Read() then
            LastExpiry := WhseEntryQry.Expiration_Date;
        WhseEntryQry.Close();
        exit(LastExpiry);
    end;

    local procedure GetItemHighbayBinCode(LocationCode: Code[10]; ItemNo: Code[20]): Code[20]
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(Highbay, true);
        if not Bin.FindSet() then
            exit('');

        repeat
            BinContent.Reset();
            BinContent.SetRange("Location Code", LocationCode);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if not BinContent.IsEmpty() then
                exit(Bin.Code);
        until Bin.Next() = 0;

        exit('');
    end;

    /// <summary>
    /// Resolves the Bin Code of the target-type-flagged bin in a given location.
    /// Returns '' when no bin carries the requested flag in that location.
    /// </summary>
    /// <summary>
    /// Resolves the BULK-flagged bin where this ITEM has a Bin Content row.
    /// Convention: one BULK bin per item per location. Among multiple
    /// BULK-flagged bins, only one will hold any given item, so we use
    /// Bin Content as the disambiguator rather than picking the first
    /// BULK bin alphabetically.
    /// Returns '' when the item has no Bin Content in any BULK bin.
    /// </summary>
    local procedure GetItemBulkBinCode(LocationCode: Code[10]; ItemNo: Code[20]): Code[20]
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(Bulk, true);
        if not Bin.FindSet() then
            exit('');

        repeat
            BinContent.Reset();
            BinContent.SetRange("Location Code", LocationCode);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if not BinContent.IsEmpty() then
                exit(Bin.Code);
        until Bin.Next() = 0;

        exit('');
    end;

    local procedure GetTargetBinCode(LocationCode: Code[10]; TargetType: Enum "Put-Away Target Zone NDPP"): Code[20]
    var
        Bin: Record Bin;
    begin
        Bin.SetRange("Location Code", LocationCode);
        case TargetType of
            TargetType::BulkDecant:
                Bin.SetRange(Bulk, true);
            TargetType::"Static":
                Bin.SetRange("Static", true);
            TargetType::Flowrack:
                Bin.SetRange(Flowrack, true);
            TargetType::HighBay:
                Bin.SetRange(HighBay, true);
        end;
        if Bin.FindFirst() then
            exit(Bin.Code);

        exit('');
    end;

    /// <summary>
    /// Returns the Main-Warehouse Bin Content row that mirrors the put-away
    /// target type — used for the Max Qty cap. Returns FALSE if no match.
    /// </summary>
    local procedure TryGetMainBinContent(ItemNo: Code[20]; TargetType: Enum "Put-Away Target Zone NDPP"; var MainBinContent: Record "Bin Content"): Boolean
    var
        BinCode: Code[20];
    begin
        // BULK: pick the BULK-flagged bin where THIS item actually lives, in
        // case multiple BULK bins exist and the item isn't in the first one
        // returned by GetTargetBinCode.
        if TargetType = TargetType::BulkDecant then
            BinCode := GetItemBulkBinCode(G_KamWhseSetupLookup.GetMainLocation(), ItemNo)
        else
            BinCode := GetTargetBinCode(G_KamWhseSetupLookup.GetMainLocation(), TargetType);
        if BinCode = '' then
            exit(false);

        MainBinContent.Reset();
        MainBinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetMainLocation());
        MainBinContent.SetRange("Bin Code", BinCode);
        MainBinContent.SetRange("Item No.", ItemNo);
        exit(MainBinContent.FindFirst());
    end;

    /// <summary>
    /// Calculates how much of this item is already reserved in the equivalent
    /// Main-Warehouse target zone PLUS the qty currently in the Receive
    /// target bin — i.e. "what the decant face will look like once today's
    /// put-away batch lands".
    /// </summary>
    local procedure CalcReservedQty(ItemNo: Code[20]; TargetType: Enum "Put-Away Target Zone NDPP"): Decimal
    var
        MainBinContent: Record "Bin Content";
        ReceiveBinContent: Record "Bin Content";
        ReceiveBinCode: Code[20];
        ReceivedQty: Decimal;
        MainQty: Decimal;
    begin
        if TryGetMainBinContent(ItemNo, TargetType, MainBinContent) then begin
            MainBinContent.CalcFields("Quantity (Base)", "Put-away Quantity (Base)", "Positive Adjmt. Qty. (Base)");
            //MainQty := MainBinContent."Quantity (Base)" + MainBinContent."Positive Adjmt. Qty. (Base)";
            MainQty := MainBinContent."Quantity (Base)";
        end;

        // BULK: pick the BULK-flagged bin where THIS item lives at Receive.
        if TargetType = TargetType::BulkDecant then
            ReceiveBinCode := GetItemBulkBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), ItemNo)
        else
            ReceiveBinCode := GetTargetBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), TargetType);
        if ReceiveBinCode <> '' then begin
            ReceiveBinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetReceiveLocation());
            ReceiveBinContent.SetRange("Bin Code", ReceiveBinCode);
            ReceiveBinContent.SetRange("Item No.", ItemNo);
            if ReceiveBinContent.FindSet() then
                repeat
                    ReceiveBinContent.CalcFields("Quantity (Base)", "Put-away Quantity (Base)", "Positive Adjmt. Qty. (Base)");
                    ReceivedQty += ReceiveBinContent."Quantity (Base)"
                                 + ReceiveBinContent."Put-away Quantity (Base)"
                                 + ReceiveBinContent."Positive Adjmt. Qty. (Base)";
                until ReceiveBinContent.Next() = 0;
        end;

        exit(MainQty + ReceivedQty);
    end;

    /// <summary>
    /// Returns the current Put-Away line's own outstanding qty IF it currently
    /// targets the requested zone — otherwise 0.
    ///
    /// Bin Content FlowFields update as soon as a Place line is inserted, so
    /// by the time HandleBinCapacity runs for the current line, that line's
    /// own qty is already inside CalcReservedQty. Adding it back here gives
    /// callers "space available BEFORE this line" — the right basis for
    /// deciding how much fits in the decant bin and how much spills to HighBay.
    /// Without this add-back, the bin would always look full.
    /// </summary>
    local procedure GetCurrentLineSelfContribution(var WhseActivityLine: Record "Warehouse Activity Line"; TargetType: Enum "Put-Away Target Zone NDPP"): Decimal
    var
        TargetBin: Code[20];
    begin
        // BULK is item-specific; other targets are single-bin-per-location.
        if TargetType = TargetType::BulkDecant then
            TargetBin := GetItemBulkBinCode(WhseActivityLine."Location Code", WhseActivityLine."Item No.")
        else
            TargetBin := GetTargetBinCode(WhseActivityLine."Location Code", TargetType);
        if TargetBin = '' then
            exit(0);
        if WhseActivityLine."Bin Code" <> TargetBin then
            exit(0);
        exit(WhseActivityLine."Qty. Outstanding (Base)");
    end;


    /// <summary>
    /// Sums totes already booked into the Receive GEN DECANT zone by un-posted
    /// put-away Place lines for the same item, EXCLUDING the line currently
    /// being processed (matched by Activity Type/No./Line No.).
    ///
    /// This catches earlier lines from the same Create Put-Away batch that
    /// have been inserted but not yet posted — without it, every line in the
    /// batch would compute the same EmptyTotes count and oversubscribe the bin.
    /// </summary>
    local procedure CountPendingFlowrackTotes(var CurrentLine: Record "Warehouse Activity Line"): Integer
    var
        OtherLine: Record "Warehouse Activity Line";
        FlowrackBin: Code[20];
        QtyPerTote: Decimal;
        Totes: Integer;
    begin
        FlowrackBin := GetTargetBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), "Put-Away Target Zone NDPP"::Flowrack);
        if FlowrackBin = '' then
            exit(0);

        OtherLine.SetCurrentKey("Item No.", "Location Code");
        OtherLine.SetRange("Item No.", CurrentLine."Item No.");
        OtherLine.SetRange("Location Code", G_KamWhseSetupLookup.GetReceiveLocation());
        OtherLine.SetRange("Activity Type", OtherLine."Activity Type"::"Put-away");
        OtherLine.SetRange("Action Type", OtherLine."Action Type"::Place);
        OtherLine.SetRange("Bin Code", FlowrackBin);
        OtherLine.SetFilter("Qty. Outstanding (Base)", '>%1', 0);
        if OtherLine.FindSet() then
            repeat
                if not IsSameLine(OtherLine, CurrentLine) then begin
                    QtyPerTote := KamToteMath.GetQtyPerTote(CurrentLine."Item No.", OtherLine."Manufacturer Code");
                    if QtyPerTote > 0 then
                        Totes += Round(OtherLine."Qty. Outstanding (Base)" / QtyPerTote, 1, '>');
                end;
            until OtherLine.Next() = 0;
        exit(Totes);
    end;

    local procedure IsSameLine(A: Record "Warehouse Activity Line"; B: Record "Warehouse Activity Line"): Boolean
    begin
        exit((A."Activity Type" = B."Activity Type") and (A."No." = B."No.") and (A."Line No." = B."Line No."));
    end;

    /// <summary>
    /// Counts whole totes of the item already staged at the Receive Flowrack bin,
    /// summed per manufacturer from posted Warehouse Entries. Subtracted from
    /// EmptyTotes in ResolveSpaceLeft so the capacity math mirrors how BULK's
    /// CalcReservedQty accounts for Receive on-hand: stock sitting at Receive is
    /// already occupying downstream Main-WH capacity even though it hasn't been
    /// decanted yet.
    ///
    /// Whole-tote rounding (Round up, matches CountPendingFlowrackTotes) is
    /// intentional — a partial tote at Receive still occupies a full tote slot's
    /// worth of downstream capacity; you can't share a slot across manufacturers.
    ///
    /// Returns 0 when no Receive Flowrack bin is configured or no matching
    /// warehouse entries exist.
    /// </summary>
    local procedure CountReceiveFlowrackTotes(ItemNo: Code[20]): Integer
    var
        ItemMfr: Record "Item Manufacturer Table";
        WhseEntry: Record "Warehouse Entry";
        ReceiveLoc: Code[20];
        ReceiveBin: Code[20];
        MfgQtyBase: Decimal;
        Totes: Integer;
    begin
        ReceiveLoc := G_KamWhseSetupLookup.GetReceiveLocation();
        ReceiveBin := GetTargetBinCode(ReceiveLoc, "Put-Away Target Zone NDPP"::Flowrack);
        if ReceiveBin = '' then
            exit(0);

        ItemMfr.SetRange("Item No", ItemNo);
        ItemMfr.SetFilter("Qty per Tote", '>%1', 0);
        if not ItemMfr.FindSet() then
            exit(0);

        // Warehouse Entry's standard keys lead with ("Item No.", "Bin Code", "Location Code", ...),
        // so the per-manufacturer CalcSums is selective even though "Manufacturer Code"
        // is a custom field outside the key.
        repeat
            WhseEntry.Reset();
            WhseEntry.SetRange("Item No.", ItemNo);
            WhseEntry.SetRange("Location Code", ReceiveLoc);
            WhseEntry.SetRange("Bin Code", ReceiveBin);
            WhseEntry.SetRange("Manufacturer Code", ItemMfr."Manufacturer Code");
            WhseEntry.CalcSums("Qty. (Base)");
            MfgQtyBase := WhseEntry."Qty. (Base)";
            if MfgQtyBase > 0 then
                Totes += Round(MfgQtyBase / ItemMfr."Qty per Tote", 1, '>');
        until ItemMfr.Next() = 0;

        exit(Totes);
    end;

    // ---------- Integration events (extension points) ----------

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRoutePutAwayLine(var WhseActivityLine: Record "Warehouse Activity Line"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterRoutePutAwayLine(var WhseActivityLine: Record "Warehouse Activity Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeHandleBinCapacity(var WhseActivityLine: Record "Warehouse Activity Line"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterHandleBinCapacity(var WhseActivityLine: Record "Warehouse Activity Line")
    begin
    end;

    var
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        KamToteMath: Codeunit "Kam Tote Math";
        G_LineSpacing: Boolean;
        G_TargetedBins: Dictionary of [Text, Boolean];
        G_ClaimScopeKey: Text;
        // Staging bin (and item) a SplitLine() spillover came from, so
        // RouteSplitLine can send that spillover to the NEXT staging bin in the
        // item's fill order rather than always to High Bay. Set only for the
        // duration of the SplitLine call inside HandleBinCapacity.
        G_SplitFromStagingType: Enum "Put-Away Target Zone NDPP";
        G_SplitFromItemNo: Code[20];
        // Net shortfall (Main Min-Qty gap MINUS older HighBay qty) that the
        // decant face is allowed to absorb for the current (Doc No. | Item No.)
        // scope. Set by the HighBay older-stock guard in RoutePutAwayLine,
        // enforced in HandleBinCapacity, drawn down by ConsumeNetShortfallCap.
        // 0 = no cap active (normal capacity rules apply unchanged).
        G_NetShortfallCap: Decimal;
        G_NetShortfallScopeKey: Text;
    //G_CurrentLineMainBin: Code[20];
}
