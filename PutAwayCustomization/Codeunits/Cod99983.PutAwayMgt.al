namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Structure;
using Microsoft.Inventory.Item;

/// <summary>
/// US 40488 — Goods-In Put-Away routing engine.
///
/// PURPOSE
///   When stock is received at the BULK location, the standard BC put-away
///   logic only puts it into a generic Put-Away zone. Kamsons need it routed
///   to one of three zones based on item flags + existing decant stock + expiry:
///
///     * BULK DECANT  — for items flagged Item.BULK = TRUE
///     * GEN DECANT   — for items flagged Item.BULK = FALSE
///     * HIGH-BAY     — overflow / older-expiry stock
///
/// HIGH-LEVEL RULES
///   1. Only triggers at the configured Receive Warehouse (e.g. BULK location).
///   2. Only acts on Put-Away Place lines from a Purchase Order source.
///   3. If existing decant stock for this item has a NEWER expiry than the
///      incoming line's expiry, the incoming line is sent to HIGH-BAY (the
///      decant face must always hold the freshest stock).
///   4. If routing the line to a decant zone would exceed the bin's Max Qty.,
///      the line is split: the spillover goes to HIGH-BAY.
///
/// DESIGN
///   This codeunit holds ALL business logic. The accompanying subscriber
///   codeunit (PutAwaySubscribers99984) only forwards events to procedures here.
///   This split makes the logic unit-testable directly without simulating
///   warehouse posting.
/// </summary>
codeunit 99983 "Put-Away Mgt. NDPP"
{
    SingleInstance = true;
    Permissions = tabledata "Warehouse Activity Line" = rm,
                  tabledata "Bin Content" = r,
                  tabledata Zone = r,
                  tabledata Item = r;

    /// <summary>
    /// Routes a freshly-created Put-Away line to its target zone & bin.
    /// Called from OnBeforeWhseActivLineInsert subscriber.
    /// </summary>
    procedure RoutePutAwayLine(var WhseActivityLine: Record "Warehouse Activity Line")
    var
        Item: Record Item;
        Zone: Record Zone;
        IsHandled: Boolean;
        LastDecantExpiry: Date;
        DecantZoneCode: Code[10];
        TargetZone: Enum "Put-Away Target Zone NDPP";
    begin
        OnBeforeRoutePutAwayLine(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        if not Item.Get(WhseActivityLine."Item No.") then
            exit;

        if not Zone.Get(WhseActivityLine."Location Code", WhseActivityLine."Zone Code") then
            exit;

        // Already in High-Bay — leave alone.
        if Zone.HighBay then
            exit;

        // 1. Decide initial target zone based on the BULK flag on the item.
        if Item.BULK then begin
            TargetZone := TargetZone::BulkDecant;
            DecantZoneCode := G_KamWhseSetupLookup.GetBulkZone(G_KamWhseSetupLookup.GetReceiveLocation());
        end else begin
            TargetZone := TargetZone::GenDecant;
            DecantZoneCode := G_KamWhseSetupLookup.GetGenDecantZone(G_KamWhseSetupLookup.GetReceiveLocation());
        end;

        // 2. Compare expiry against existing decant stock.
        LastDecantExpiry := GetLatestDecantExpiry(WhseActivityLine."Item No.", DecantZoneCode);

        ClearReservedQty();

        if (LastDecantExpiry = 0D) or (WhseActivityLine."Expiration Date" <= LastDecantExpiry) then begin
            AssignZoneBin(WhseActivityLine, TargetZone);
            G_BinContentQty := CalcReservedQty(WhseActivityLine."Item No.", DecantZoneCode);
        end else
            AssignZoneBin(WhseActivityLine, TargetZone::HighBay);

        OnAfterRoutePutAwayLine(WhseActivityLine);
    end;

    /// <summary>
    /// After the Put-Away line is inserted, check whether it would exceed the
    /// destination bin's Max Qty. If so, split it and send the overflow to High-Bay.
    /// </summary>
    procedure HandleBinCapacity(var WhseActivityLine: Record "Warehouse Activity Line")
    var
        BinContent: Record "Bin Content";
        SplitLine: Record "Warehouse Activity Line";
        Zone: Record Zone;
        IsHandled: Boolean;
        DecantZoneCode: Code[10];
        BinMaxBaseQty: Decimal;
        SpaceLeftInDecant: Decimal;
    begin
        OnBeforeHandleBinCapacity(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        if not Zone.Get(WhseActivityLine."Location Code", WhseActivityLine."Zone Code") then
            exit;

        // Only relevant if the line is currently sitting in a Decant zone.
        if Zone.HighBay then
            exit;
        if not (Zone.BULK or Zone.General) then
            exit;

        // Look at the SAME-item bin in the MAIN warehouse — that bin's Max Qty
        // dictates how much can fit at the decant face once it has been replenished.
        if Zone.BULK then
            DecantZoneCode := G_KamWhseSetupLookup.GetBulkZone(G_KamWhseSetupLookup.GetMainLocation())
        else
            DecantZoneCode := G_KamWhseSetupLookup.GetGenDecantZonefromBinContent(G_KamWhseSetupLookup.GetMainLocation(), WhseActivityLine."Item No.");

        BinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetMainLocation());
        BinContent.SetRange("Zone Code", DecantZoneCode);
        BinContent.SetRange("Item No.", WhseActivityLine."Item No.");
        if not BinContent.FindFirst() then
            exit;

        if BinContent."Max. Qty." <= 0 then
            exit; // No cap — nothing to enforce.

        BinMaxBaseQty := BinContent."Max. Qty." * BinContent."Qty. per Unit of Measure";
        SpaceLeftInDecant := BinMaxBaseQty - G_BinContentQty;

        // Decant bin already at/over capacity — push everything to High-Bay.
        if SpaceLeftInDecant <= 0 then begin
            AssignZoneBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
            WhseActivityLine.Modify();
            ClearReservedQty();
            exit;
        end;

        // Decant bin can absorb the whole line — leave alone.
        if (G_BinContentQty + WhseActivityLine."Qty. (Base)") <= BinMaxBaseQty then begin
            ClearReservedQty();
            exit;
        end;

        // Split: keep `SpaceLeftInDecant` in the decant zone, send the rest to High-Bay.
        WhseActivityLine.Validate("Qty. to Handle (Base)", SpaceLeftInDecant);
        WhseActivityLine.Modify();

        SplitLine.Copy(WhseActivityLine);
        G_LineSpacing := true;
        WhseActivityLine.SplitLine(SplitLine);
        WhseActivityLine.Copy(SplitLine);
        G_LineSpacing := false;

        ClearReservedQty();

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
        exit(0); // 0 = standard BC behaviour
    end;

    /// <summary>
    /// Returns TRUE only for Put-Away Place lines from a Purchase Order
    /// at the Receive Warehouse — the only context US 40488 cares about.
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
    /// Assigns the target Zone Code and (if found) Bin Code on a Put-Away line.
    /// If no bin exists for the item at that zone, Bin Code is cleared so the
    /// user is forced to pick one — preferable to silently using the wrong bin.
    /// </summary>
    local procedure AssignZoneBin(var WhseActivityLine: Record "Warehouse Activity Line"; TargetZone: Enum "Put-Away Target Zone NDPP")
    var
        Zone: Record Zone;
        BinContent: Record "Bin Content";
    begin
        Zone.SetRange("Location Code", WhseActivityLine."Location Code");
        case TargetZone of
            TargetZone::BulkDecant:
                Zone.SetRange(BULK, true);
            TargetZone::GenDecant:
                Zone.SetRange(General, true);
            TargetZone::HighBay:
                Zone.SetRange(HighBay, true);
        end;
        if not Zone.FindFirst() then
            exit;

        WhseActivityLine.Validate("Zone Code", Zone.Code);

        BinContent.SetRange("Location Code", WhseActivityLine."Location Code");
        BinContent.SetRange("Zone Code", Zone.Code);
        BinContent.SetRange("Item No.", WhseActivityLine."Item No.");
        if BinContent.FindFirst() then
            WhseActivityLine.Validate("Bin Code", BinContent."Bin Code")
        else
            WhseActivityLine."Bin Code" := '';
    end;

    /// <summary>
    /// Returns the LATEST Expiration Date currently held in the given decant
    /// zone for the given item (with positive on-hand qty).
    /// </summary>
    local procedure GetLatestDecantExpiry(ItemNo: Code[20]; ZoneCode: Code[10]): Date
    var
        WhseEntryQry: Query "Whse Entry Lot Details NDPP";
        LastExpiry: Date;
    begin
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
    /// Calculates how much of this item is already reserved in the
    /// equivalent main-warehouse decant zone PLUS any inbound put-away qty
    /// at the receive zone — i.e. "what's the decant face going to look like
    /// once the current put-away batch lands".
    /// </summary>
    local procedure CalcReservedQty(ItemNo: Code[20]; ReceiveZoneCode: Code[10]): Decimal
    var
        Item: Record Item;
        MainBinContent: Record "Bin Content";
        ReceiveBinContent: Record "Bin Content";
        MainZoneCode: Code[10];
        ReceivedQty: Decimal;
        Total: Decimal;
    begin
        if not Item.Get(ItemNo) then
            exit(0);

        if Item.BULK then
            MainZoneCode := G_KamWhseSetupLookup.GetBulkZone(G_KamWhseSetupLookup.GetMainLocation())
        else
            MainZoneCode := G_KamWhseSetupLookup.GetGenDecantZone(G_KamWhseSetupLookup.GetMainLocation());

        // Existing main-warehouse decant qty
        MainBinContent.SetRange("Location Code", G_KamWhseSetupLookup.GetMainLocation());
        MainBinContent.SetRange("Zone Code", MainZoneCode);
        MainBinContent.SetRange("Item No.", ItemNo);
        if MainBinContent.FindFirst() then
            MainBinContent.CalcFields("Quantity (Base)", "Put-away Quantity (Base)", "Positive Adjmt. Qty. (Base)");

        // Stock currently sitting in the receive-warehouse decant zone (today's batch)
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

        Total := MainBinContent."Quantity (Base)"
               + MainBinContent."Positive Adjmt. Qty. (Base)"
               + ReceivedQty;
        exit(Total);
    end;

    procedure ClearReservedQty()
    begin
        Clear(G_BinContentQty);
    end;

    /// <summary>
    /// Forces a Put-Away line into the High-Bay zone — used for split-line
    /// spillover from HandleBinCapacity.
    /// </summary>
    procedure RoutePutAwayLineAsHighBay(var WhseActivityLine: Record "Warehouse Activity Line")
    begin
        AssignZoneBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
    end;

    procedure StartExecution()
    begin
        Clear(G_IsExecuting);
        G_IsExecuting := true;
    end;

    procedure IsExecuting(): Boolean
    begin
        exit(G_IsExecuting);
    end;

    procedure StopExecution()
    begin
        G_IsExecuting := false;
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
        //G_Events: Codeunit Events;
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        G_BinContentQty: Decimal;
        G_IsExecuting: Boolean;
        G_LineSpacing: Boolean;
}
