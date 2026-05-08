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
///   3. BULK Min-Qty top-up bypass: for BULK items, if on-hand qty across the
///      Main-WH and Receive BULK DECANT bins is below the Main-WH bin's Min
///      Qty, the line is routed to BULK DECANT regardless of expiry. The
///      Max-Qty cap in HandleBinCapacity still splits overflow to HighBay.
///   4. Expiry check (when not bypassed): if incoming line's expiry is NEWER
///      than the latest existing expiry already in the target bin, the entire
///      line is sent to HighBay (the decant face must keep the freshest stock).
///   5. If routing the line to the target bin would exceed the equivalent
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

        if not Item.Get(WhseActivityLine."Item No.") then
            exit;

        // Already in the High-Bay bin — leave alone.
        if IsLineInHighBay(WhseActivityLine) then
            exit;

        // Defensive: prior runs of HandleBinCapacity that exited mid-split could
        // theoretically leave G_LineSpacing stuck at TRUE — reset on every entry.
        G_LineSpacing := false;

        // 1. Decide initial target bin from item flags.
        TargetType := DetermineTargetType(Item);

        // 2. Min-Qty top-up bypass (BULK only):
        //    If on-hand qty in BULK DECANT (Main + Receive) is below Min Qty,
        //    skip the expiry check and route everything to BULK DECANT — the
        //    Max-Qty cap in HandleBinCapacity will still split overflow to
        //    HighBay. The decant face must stay above Min Qty even at the cost
        //    of holding fresher stock with older.
        if (TargetType = TargetType::BulkDecant) and IsBulkDecantBelowMinQty(WhseActivityLine."Item No.") then begin
            AssignTargetBin(WhseActivityLine, TargetType);
            OnAfterRoutePutAwayLine(WhseActivityLine);
            exit;
        end;

        // 3. Otherwise compare expiry against the latest expiry already in the target bin.
        LastDecantExpiry := GetLatestDecantExpiry(WhseActivityLine."Item No.", TargetType);

        if (LastDecantExpiry = 0D) or (WhseActivityLine."Expiration Date" <= LastDecantExpiry) then
            AssignTargetBin(WhseActivityLine, TargetType)
        else
            // Incoming stock is fresher than what's on the decant face — push to HighBay.
            AssignTargetBin(WhseActivityLine, TargetType::HighBay);

        OnAfterRoutePutAwayLine(WhseActivityLine);
    end;

    /// <summary>
    /// TRUE when on-hand qty for the item across Main WH and Receive Location
    /// BULK DECANT bins is below the Main-WH BULK bin's Min Qty (in base units).
    /// Drives the "top up regardless of expiry" rule for BULK items.
    /// </summary>
    local procedure IsBulkDecantBelowMinQty(ItemNo: Code[20]): Boolean
    var
        MainBinContent: Record "Bin Content";
        ReceiveBinContent: Record "Bin Content";
        ReceiveZone: Code[10];
        AvailableBaseQty: Decimal;
        MinBaseQty: Decimal;
    begin
        if not TryGetMainBinContent(ItemNo, "Put-Away Target Zone NDPP"::BulkDecant, MainBinContent) then
            exit(false); // No Main WH BULK bin / no setup — can't evaluate, skip the bypass.

        MinBaseQty := MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
        if MinBaseQty <= 0 then
            exit(false); // No Min Qty configured — bypass disabled for this item.

        MainBinContent.CalcFields("Quantity (Base)");
        AvailableBaseQty := MainBinContent."Quantity (Base)";

        ReceiveZone := GetTargetZoneCode(G_KamWhseSetupLookup.GetReceiveLocation(), "Put-Away Target Zone NDPP"::BulkDecant);
        if ReceiveZone <> '' then begin
            ReceiveBinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetReceiveLocation());
            ReceiveBinContent.SetRange("Zone Code", ReceiveZone);
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
        MainBinContent: Record "Bin Content";
        SplitLine: Record "Warehouse Activity Line";
        IsHandled: Boolean;
        TargetType: Enum "Put-Away Target Zone NDPP";
        SpaceLeftInDecant: Decimal;
    begin
        OnBeforeHandleBinCapacity(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        if not Item.Get(WhseActivityLine."Item No.") then
            exit;

        // Defensive: don't trust prior state for the SplitLine signal.
        G_LineSpacing := false;

        // Only relevant if the line is currently sitting in a Decant bin (Bulk / Static / Flowrack).
        if IsLineInHighBay(WhseActivityLine) then
            exit;
        if not IsLineInDecantBin(WhseActivityLine) then
            exit;

        TargetType := DetermineTargetType(Item);

        if not TryGetMainBinContent(WhseActivityLine."Item No.", TargetType, MainBinContent) then
            exit;

        SpaceLeftInDecant := ResolveSpaceLeft(WhseActivityLine, Item, MainBinContent);

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
                exit(TargetType::GenDecant);
        end;
    end;

    /// <summary>
    /// Returns the base-qty SPACE LEFT in the put-away target bin.
    ///
    ///   Flowrack -> EmptyTotes x QtyPerTote(line.Manufacturer)
    ///               EmptyTotes already nets out filled + pending put-away
    ///               totes (CountPendingFlowrackTotes), so the result is the
    ///               actual space available.
    ///
    ///   BULK / Static -> (Max Qty x Qty per UoM)
    ///                    - CalcReservedQty(...)               // live qty in zone
    ///                    + (current line's qty if it targets this zone)
    ///                    Bin Content updates as soon as a Place line is inserted,
    ///                    so by the time HandleBinCapacity runs, the current
    ///                    line's own qty is already counted inside CalcReservedQty.
    ///                    Adding it back gives "space available BEFORE this line"
    ///                    — the correct basis for deciding how much of the line
    ///                    fits in the decant bin and how much spills to HighBay.
    ///
    /// Returns 0 (or less) when there's no room. If a Flowrack line lacks tote
    /// setup, falls back to the Max Qty path so incomplete master data doesn't
    /// dump everything to HighBay.
    /// </summary>
    local procedure ResolveSpaceLeft(var WhseActivityLine: Record "Warehouse Activity Line"; Item: Record Item; var MainBinContent: Record "Bin Content"): Decimal
    var
        TargetType: Enum "Put-Away Target Zone NDPP";
        QtyPerTote: Decimal;
        BinMaxBaseQty: Decimal;
        TargetTotes: Integer;
        FilledTotes: Integer;
        EmptyTotes: Integer;
    begin
        if Item."Routing Type" = Item."Routing Type"::Flowrack then begin
            QtyPerTote := KamToteMath.GetQtyPerTote(WhseActivityLine."Item No.", WhseActivityLine."Manufacturer Code");
            TargetTotes := MainBinContent."Number of Totes in a Bin";
            if (QtyPerTote > 0) and (TargetTotes > 0) then begin
                // FilledTotes counts posted Warehouse Entries.
                // CountPendingFlowrackTotes counts outstanding put-away lines
                // pointing at the Receive GEN DECANT zone (earlier lines in the
                // same batch + any prior un-posted put-aways), excluding the
                // current line — without it, line #2 of a batch would re-claim
                // the same totes line #1 just consumed.
                FilledTotes := KamToteMath.CountTotesInFLOWRACKBin(MainBinContent);
                EmptyTotes := TargetTotes - FilledTotes - CountPendingFlowrackTotes(WhseActivityLine);
                if EmptyTotes < 0 then
                    EmptyTotes := 0;
                exit(EmptyTotes * QtyPerTote);
            end;
        end;

        // BULK / Static / Flowrack-fallback — Max Qty rule, net of qty already
        // in the zone, with the current line's own qty added back so we're
        // computing "space BEFORE this line", not "space AFTER".
        BinMaxBaseQty := MainBinContent."Max. Qty." * MainBinContent."Qty. per Unit of Measure";
        if BinMaxBaseQty <= 0 then
            exit(0);

        TargetType := DetermineTargetType(Item);
        exit(BinMaxBaseQty
             - CalcReservedQty(WhseActivityLine."Item No.", TargetType)
             + GetCurrentLineSelfContribution(WhseActivityLine, TargetType));
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
    begin
        Bin.SetRange("Location Code", WhseActivityLine."Location Code");
        case TargetType of
            TargetType::BulkDecant:
                Bin.SetRange(Bulk, true);
            TargetType::"Static":
                Bin.SetRange("Static", true);
            TargetType::GenDecant:
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
        ZoneCode: Code[10];
        LastExpiry: Date;
    begin
        ZoneCode := GetTargetZoneCode(G_KamWhseSetupLookup.GetReceiveLocation(), TargetType);
        if ZoneCode = '' then
            exit(0D);

        WhseEntryQry.SetFilter(WhseEntryQry.Item_No_, '%1', ItemNo);
        WhseEntryQry.SetFilter(WhseEntryQry.Location_Code, '%1', G_KamWhseSetupLookup.GetReceiveLocation());
        WhseEntryQry.SetFilter(WhseEntryQry.Zone_Code, '%1', ZoneCode);
        WhseEntryQry.SetFilter(WhseEntryQry.Qty_Base, '>%1', 0);
        WhseEntryQry.TopNumberOfRows(1);
        WhseEntryQry.Open();
        if WhseEntryQry.Read() then
            LastExpiry := WhseEntryQry.Expiration_Date;
        WhseEntryQry.Close();
        exit(LastExpiry);
    end;

    /// <summary>
    /// Resolves the Zone Code that hosts the target-type bin in a given location.
    /// </summary>
    local procedure GetTargetZoneCode(LocationCode: Code[10]; TargetType: Enum "Put-Away Target Zone NDPP"): Code[10]
    var
        Bin: Record Bin;
    begin
        Bin.SetRange("Location Code", LocationCode);
        case TargetType of
            TargetType::BulkDecant:
                Bin.SetRange(Bulk, true);
            TargetType::"Static":
                Bin.SetRange("Static", true);
            TargetType::GenDecant:
                Bin.SetRange(Flowrack, true);
            TargetType::HighBay:
                Bin.SetRange(HighBay, true);
        end;
        if Bin.FindFirst() then
            exit(Bin."Zone Code")
        else
            exit('');
    end;

    /// <summary>
    /// Returns the Main-Warehouse Bin Content row that mirrors the put-away
    /// target type — used for the Max Qty cap. Returns FALSE if no match.
    /// </summary>
    local procedure TryGetMainBinContent(ItemNo: Code[20]; TargetType: Enum "Put-Away Target Zone NDPP"; var MainBinContent: Record "Bin Content"): Boolean
    var
        ZoneCode: Code[10];
    begin
        ZoneCode := GetTargetZoneCode(G_KamWhseSetupLookup.GetMainLocation(), TargetType);
        if ZoneCode = '' then
            exit(false);

        MainBinContent.Reset();
        MainBinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetMainLocation());
        MainBinContent.SetRange("Zone Code", ZoneCode);
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
        ReceiveZoneCode: Code[10];
        ReceivedQty: Decimal;
        MainQty: Decimal;
    begin
        if TryGetMainBinContent(ItemNo, TargetType, MainBinContent) then begin
            MainBinContent.CalcFields("Quantity (Base)", "Put-away Quantity (Base)", "Positive Adjmt. Qty. (Base)");
            MainQty := MainBinContent."Quantity (Base)" + MainBinContent."Positive Adjmt. Qty. (Base)";
        end;

        ReceiveZoneCode := GetTargetZoneCode(G_KamWhseSetupLookup.GetReceiveLocation(), TargetType);
        if ReceiveZoneCode <> '' then begin
            ReceiveBinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetReceiveLocation());
            ReceiveBinContent.SetRange("Zone Code", ReceiveZoneCode);
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
        TargetZone: Code[10];
    begin
        TargetZone := GetTargetZoneCode(WhseActivityLine."Location Code", TargetType);
        if TargetZone = '' then
            exit(0);
        if WhseActivityLine."Zone Code" <> TargetZone then
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
        GenDecantZone: Code[10];
        QtyPerTote: Decimal;
        Totes: Integer;
    begin
        GenDecantZone := GetTargetZoneCode(G_KamWhseSetupLookup.GetReceiveLocation(), "Put-Away Target Zone NDPP"::GenDecant);
        if GenDecantZone = '' then
            exit(0);

        OtherLine.SetCurrentKey("Item No.", "Location Code");
        OtherLine.SetRange("Item No.", CurrentLine."Item No.");
        OtherLine.SetRange("Location Code", G_KamWhseSetupLookup.GetReceiveLocation());
        OtherLine.SetRange("Activity Type", OtherLine."Activity Type"::"Put-away");
        OtherLine.SetRange("Action Type", OtherLine."Action Type"::Place);
        OtherLine.SetRange("Zone Code", GenDecantZone);
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
}
