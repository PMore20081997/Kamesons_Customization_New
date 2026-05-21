namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Structure;
using Microsoft.Inventory.Item;

/// <summary>
/// US 40488 — Goods-In Put-Away routing engine.
///
/// PURPOSE
///   When stock is received at the Receive Location (PICK BULK), route the
///   put-away line based on Item."Routing Type":
///
///     Routing Type = BULK                    -> Bulk bin
///     Routing Type = Static or Flowrack      -> Flowrack (GEN DECANT) bin
///     overflow / newer expiry / capacity hit -> HighBay bin
///
///   At put-away, Static and Flowrack items share the GEN DECANT bin and use
///   the same Max-Qty rule against the Main-WH bin. The Static-vs-Flowrack
///   split only matters during the decant phase (different capacity rules
///   there) and is not a put-away concern.
///
///   Routing booleans live on Bin (Bulk / Static / Flowrack / HighBay).
///
/// HIGH-LEVEL RULES
///   1. Only triggers at the configured Receive Location.
///   2. Only acts on Put-Away Place lines from a Purchase Order source.
///   3. Master-data gate: if NO Bin Content row exists in the Main WH target
///      bin for this item, the entire line is routed to HighBay. Items
///      without configured master data must not land on an unmanaged decant.
///   4. BULK Min-Qty top-up bypass: for BULK items, if on-hand qty across the
///      Main-WH and Receive BULK DECANT bins is below the Main-WH bin's Min
///      Qty, the line is routed to BULK DECANT regardless of expiry. The
///      Max-Qty cap in HandleBinCapacity still splits overflow to HighBay.
///   5. Expiry check (when not bypassed): if incoming line's expiry is NEWER
///      than the latest existing expiry already in the target bin, the entire
///      line is sent to HighBay (the decant face must keep the freshest stock).
///   6. If routing the line to the target bin would exceed the equivalent
///      Main-Warehouse bin's Max Qty, the line is split: the spillover goes
///      to HighBay.
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
        Item: Record Item;
        IsHandled: Boolean;
        LastDecantExpiry: Date;
        TargetType: Enum "Put-Away Target Zone NDPP";
    begin
        OnBeforeRoutePutAwayLine(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        if not GetCachedItem(WhseActivityLine."Item No.", Item) then
            exit;

        // Already in the High-Bay bin — leave alone.
        if IsLineInHighBay(WhseActivityLine) then
            exit;

        // Defensive: prior runs of HandleBinCapacity that exited mid-split could
        // theoretically leave G_LineSpacing stuck at TRUE — reset on every entry.
        G_LineSpacing := false;

        // 1. Decide initial target bin from item flags.
        TargetType := DetermineTargetType(Item);

        // 2. Master-data gate: if no Bin Content row exists in Main WH for this
        //    item at any bin matching the routing type, treat as unconfigured
        //    and route everything to HighBay. Prevents stock landing on a
        //    decant face that has no Min / Max / Number of Totes set up.
        //    For Flowrack / Static, "any" means across all flagged bins.
        if not HasMainWHBinContent(WhseActivityLine."Item No.", Item."Routing Type") then begin
            AssignTargetBin(WhseActivityLine, TargetType::HighBay);
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
        ReceiveBin: Code[20];
        AvailableBaseQty: Decimal;
        MinBaseQty: Decimal;
    begin
        // HighBay is not a decant face — no Min Qty bypass concept.
        if TargetType = TargetType::HighBay then
            exit(false);

        MainLocation := G_KamWhseSetupLookup.GetMainLocation();

        // Flowrack / Static: walk every flagged Main bin that holds this item.
        // Return TRUE on the first bin found below its own Min Qty.
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
            repeat
                MainBinContent.Reset();
                MainBinContent.SetRange("Location Code", MainLocation);
                MainBinContent.SetRange("Bin Code", Bin.Code);
                MainBinContent.SetRange("Item No.", ItemNo);
                if MainBinContent.FindFirst() then begin
                    MinBaseQty := MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
                    if MinBaseQty > 0 then begin
                        MainBinContent.CalcFields("Quantity (Base)");
                        if MainBinContent."Quantity (Base)" < MinBaseQty then
                            exit(true);
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
        AvailableBaseQty := MainBinContent."Quantity (Base)";

        ReceiveBin := GetItemBulkBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), ItemNo);

        if ReceiveBin <> '' then begin
            ReceiveBinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetReceiveLocation());
            ReceiveBinContent.SetRange("Bin Code", ReceiveBin);
            ReceiveBinContent.SetRange("Item No.", ItemNo);
            if ReceiveBinContent.FindSet() then
                repeat
                    ReceiveBinContent.CalcFields("Quantity (Base)");
                    AvailableBaseQty += ReceiveBinContent."Quantity (Base)";
                until ReceiveBinContent.Next() = 0;
        end;

        exit(AvailableBaseQty < MinBaseQty);
    end;

    /// <summary>
    /// After the Put-Away line is inserted, check whether it would exceed the
    /// Main-WH equivalent bin's Max Qty. If so, split it and send the overflow
    /// to HighBay.
    /// </summary>
    procedure HandleBinCapacity(var WhseActivityLine: Record "Warehouse Activity Line")
    var
        Item: Record Item;
        SplitLine: Record "Warehouse Activity Line";
        IsHandled: Boolean;
        SpaceLeftInDecant: Decimal;
    begin
        OnBeforeHandleBinCapacity(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        if not GetCachedItem(WhseActivityLine."Item No.", Item) then
            exit;

        // Defensive: don't trust prior state for the SplitLine signal.
        G_LineSpacing := false;

        // Only relevant if the line is currently sitting in a Decant bin (Bulk / Static / Flowrack).
        if IsLineInHighBay(WhseActivityLine) then
            exit;
        if not IsLineInDecantBin(WhseActivityLine) then
            exit;

        SpaceLeftInDecant := ResolveSpaceLeft(WhseActivityLine, Item);

        // Decant bin already at/over capacity — push everything to High-Bay.
        if SpaceLeftInDecant <= 0 then begin
            AssignTargetBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
            WhseActivityLine.Modify();
            exit;
        end;

        // Decant bin can absorb the whole line — leave alone.
        if WhseActivityLine."Qty. (Base)" <= SpaceLeftInDecant then
            exit;

        // Split: keep `SpaceLeftInDecant` in the decant bin, send the rest to HighBay.
        WhseActivityLine.Validate("Qty. to Handle (Base)", SpaceLeftInDecant);
        WhseActivityLine.Modify();

        SplitLine.Copy(WhseActivityLine);
        G_LineSpacing := true;
        WhseActivityLine.SplitLine(SplitLine);
        WhseActivityLine.Copy(SplitLine);
        G_LineSpacing := false;

        OnAfterHandleBinCapacity(WhseActivityLine);
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
    local procedure DetermineTargetType(Item: Record Item): Enum "Put-Away Target Zone NDPP"
    var
        TargetType: Enum "Put-Away Target Zone NDPP";
    begin
        case Item."Routing Type" of
            Item."Routing Type"::BULK:
                exit(TargetType::BulkDecant);
            else
                // Static and Flowrack both route to GEN DECANT at put-away.
                exit(TargetType::Flowrack);
        end;
    end;

    /// <summary>
    /// Returns the base-qty SPACE LEFT in the put-away target bin.
    ///
    ///   Flowrack / Static -> SumMainWHEmptyTotes(item, RoutingType) x QtyPerTote
    ///                        Empty totes summed across ALL Main WH bins flagged
    ///                        Flowrack (Flowrack items) or Static (Static items).
    ///                        Receive Location still places into the single
    ///                        Receive Flowrack bin — per-bin distribution at
    ///                        Main WH happens in the decant phase.
    ///                        CountPendingFlowrackTotes nets out earlier lines
    ///                        in the same batch that already claimed totes.
    ///
    ///   BULK              -> (Max Qty x Qty per UoM)
    ///                        - CalcReservedQty(...)
    ///                        + (current line's qty if it targets this zone)
    ///                        Single Main WH BULK bin. Adding current-line back
    ///                        gives "space BEFORE this line" since Bin Content
    ///                        already counts it post-insert.
    ///
    /// Returns 0 when there's no room. For Flowrack/Static, a missing tote
    /// setup (no QtyPerTote / no Number-of-Totes in Main WH bins) yields 0 →
    /// entire line to HighBay.
    /// </summary>
    local procedure ResolveSpaceLeft(var WhseActivityLine: Record "Warehouse Activity Line"; Item: Record Item): Decimal
    var
        MainBinContent: Record "Bin Content";
        TargetType: Enum "Put-Away Target Zone NDPP";
        QtyPerTote: Decimal;
        BinMaxBaseQty: Decimal;
        EmptyTotes: Integer;
    begin
        if Item."Routing Type" in [Item."Routing Type"::Flowrack, Item."Routing Type"::"Static"] then begin
            QtyPerTote := KamToteMath.GetQtyPerTote(WhseActivityLine."Item No.", WhseActivityLine."Manufacturer Code");
            if QtyPerTote <= 0 then
                exit(0);

            EmptyTotes := SumMainWHEmptyTotes(WhseActivityLine."Item No.", Item."Routing Type")
                          - CountPendingFlowrackTotes(WhseActivityLine);
            if EmptyTotes < 0 then
                EmptyTotes := 0;
            exit(EmptyTotes * QtyPerTote);
        end;

        // BULK — Max Qty rule against the single Main WH BULK bin.
        TargetType := DetermineTargetType(Item);
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
    local procedure SumMainWHEmptyTotes(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Integer
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
        TotalEmpty: Integer;
        BinEmpty: Integer;
        FilledTotes: Integer;
        TargetTotes: Integer;
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
            BinContent.Reset();
            BinContent.SetRange("Location Code", MainLocation);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if BinContent.FindFirst() then begin
                TargetTotes := BinContent."Number of Totes in a Bin";
                if TargetTotes > 0 then begin
                    FilledTotes := KamToteMath.CountTotesInFLOWRACKBin(BinContent);
                    BinEmpty := TargetTotes - FilledTotes;
                    if BinEmpty > 0 then
                        TotalEmpty += BinEmpty;
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
        if TargetType = TargetType::BulkDecant then
            BinCode := GetItemBulkBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), ItemNo)
        else
            BinCode := GetTargetBinCode(G_KamWhseSetupLookup.GetReceiveLocation(), TargetType);
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
    /// <summary>
    /// TRUE when master data exists for this item in Main WH at any bin
    /// matching the item's routing type.
    ///   BULK              -> single Bulk-flagged bin must have a Bin Content row.
    ///   Flowrack / Static -> ANY Flowrack/Static-flagged bin must have one.
    /// Items without setup go to HighBay instead of an unmanaged decant bin.
    /// </summary>
    local procedure HasMainWHBinContent(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Boolean
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
        MainLocation: Code[20];
        Dummy: Record "Bin Content";
    begin
        if RoutingType = RoutingType::BULK then
            exit(TryGetMainBinContent(ItemNo, "Put-Away Target Zone NDPP"::BulkDecant, Dummy));

        MainLocation := G_KamWhseSetupLookup.GetMainLocation();
        Bin.SetRange("Location Code", MainLocation);
        case RoutingType of
            RoutingType::Flowrack:
                Bin.SetRange(Flowrack, true);
            RoutingType::"Static":
                Bin.SetRange("Static", true);
            else
                exit(false);
        end;
        if not Bin.FindSet() then
            exit(false);

        repeat
            BinContent.Reset();
            BinContent.SetRange("Location Code", MainLocation);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if not BinContent.IsEmpty() then
                exit(true);
        until Bin.Next() = 0;

        exit(false);
    end;

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
            MainQty := MainBinContent."Quantity (Base)" + MainBinContent."Positive Adjmt. Qty. (Base)";
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
    /// Forces a Put-Away line into the High-Bay bin — used for split-line
    /// spillover from HandleBinCapacity.
    /// </summary>
    procedure RoutePutAwayLineAsHighBay(var WhseActivityLine: Record "Warehouse Activity Line")
    begin
        AssignTargetBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
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

    // Returns the Item record for ItemNo, reusing the cached copy when the same
    // item appears on consecutive lines (e.g. multiple lot numbers, one line each).
    // SingleInstance keeps G_CachedItem alive for the lifetime of the batch.
    local procedure GetCachedItem(ItemNo: Code[20]; var Item: Record Item): Boolean
    begin
        if G_CachedItemNo = ItemNo then begin
            Item := G_CachedItem;
            exit(true);
        end;
        if not Item.Get(ItemNo) then
            exit(false);
        G_CachedItem := Item;
        G_CachedItemNo := ItemNo;
        exit(true);
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
        G_CachedItemNo: Code[20];
        G_CachedItem: Record Item;
}
