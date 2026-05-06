namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Structure;
using Microsoft.Inventory.Item;

/// <summary>
/// US 40488 — Goods-In Put-Away routing engine.
///
/// PURPOSE
///   When stock is received at the Receive Location (PICK BULK), route the
///   put-away line to one of four bins based on item flags:
///
///     Item.BULK   = TRUE                     -> Bulk bin
///     Item.Static = TRUE                     -> Static bin
///     both flags  = FALSE                    -> Flowrack bin   (was GEN DECANT)
///     overflow / older expiry / capacity hit -> HighBay bin
///
///   Boolean flags now live on Bin (Bulk / Static / Flowrack / HighBay)
///   rather than on Zone. Item.BULK and Item.Static are mutually exclusive.
///
/// HIGH-LEVEL RULES
///   1. Only triggers at the configured Receive Location.
///   2. Only acts on Put-Away Place lines from a Purchase Order source.
///   3. If incoming line's expiry is NEWER than the latest existing expiry
///      already on the target bin, the entire line is sent to HighBay
///      (the decant face must keep the freshest stock).
///   4. If routing the line to the target bin would exceed the equivalent
///      Main-Warehouse bin's Max Qty, the line is split: the spillover goes
///      to HighBay.
/// </summary>
codeunit 99983 "Put-Away Mgt. NDPP"
{
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

        // 1. Decide initial target bin from item flags (BULK and Static are mutually exclusive).
        TargetType := DetermineTargetType(Item);

        // 2. Compare expiry against the latest expiry already in the target bin.
        LastDecantExpiry := GetLatestDecantExpiry(WhseActivityLine."Item No.", TargetType);

        ClearReservedQty();

        if (LastDecantExpiry = 0D) or (WhseActivityLine."Expiration Date" <= LastDecantExpiry) then begin
            AssignTargetBin(WhseActivityLine, TargetType);
            G_BinContentQty := CalcReservedQty(WhseActivityLine."Item No.", TargetType);
        end else begin
            // Incoming stock is fresher than what's on the decant face — push to HighBay.
            //
            // FUTURE — Min Qty fallback (commented until confirmed):
            //   If existing target-bin stock is BELOW Min Qty, keep enough of the
            //   incoming line to top the bin up to Min Qty and only send the
            //   remainder to HighBay. Uncomment the block below once approved.
            //
            // ApplyMinQtyFallbackOrHighBay(WhseActivityLine, TargetType);
            AssignTargetBin(WhseActivityLine, TargetType::HighBay);
        end;

        OnAfterRoutePutAwayLine(WhseActivityLine);
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
        BinMaxBaseQty: Decimal;
        SpaceLeftInDecant: Decimal;
    begin
        OnBeforeHandleBinCapacity(WhseActivityLine, IsHandled);
        if IsHandled then
            exit;

        if not IsEligibleForRouting(WhseActivityLine) then
            exit;

        if not Item.Get(WhseActivityLine."Item No.") then
            exit;

        // Only relevant if the line is currently sitting in a Decant bin (Bulk / Static / Flowrack).
        if IsLineInHighBay(WhseActivityLine) then
            exit;
        if not IsLineInDecantBin(WhseActivityLine) then
            exit;

        TargetType := DetermineTargetType(Item);

        if not TryGetMainBinContent(WhseActivityLine."Item No.", TargetType, MainBinContent) then
            exit;

        if MainBinContent."Max. Qty." <= 0 then
            exit; // No cap — nothing to enforce.

        BinMaxBaseQty := MainBinContent."Max. Qty." * MainBinContent."Qty. per Unit of Measure";
        SpaceLeftInDecant := BinMaxBaseQty - G_BinContentQty;

        // Decant bin already at/over capacity — push everything to High-Bay.
        if SpaceLeftInDecant <= 0 then begin
            AssignTargetBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
            WhseActivityLine.Modify();
            ClearReservedQty();
            exit;
        end;

        // Decant bin can absorb the whole line — leave alone.
        if (G_BinContentQty + WhseActivityLine."Qty. (Base)") <= BinMaxBaseQty then begin
            ClearReservedQty();
            exit;
        end;

        // Split: keep `SpaceLeftInDecant` in the decant bin, send the rest to HighBay.
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

    /// <summary>Maps Item flags to the target bin type.</summary>
    local procedure DetermineTargetType(Item: Record Item): Enum "Put-Away Target Zone NDPP"
    var
        TargetType: Enum "Put-Away Target Zone NDPP";
    begin
        if Item.BULK then
            exit(TargetType::BulkDecant);
        if Item."Static" then
            exit(TargetType::"Static");
        exit(TargetType::GenDecant);
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
            exit(Bin."Zone Code");
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

    // ---------------------------------------------------------------------
    // FUTURE — Min Qty fallback when incoming stock is fresher than decant.
    //
    // Today, when the incoming line's expiry is newer than what's on the
    // decant face, the whole line is sent to HighBay so the older stock is
    // consumed first. The drawback: if the existing decant stock is below
    // Min Qty, the decant face stays under-stocked until a manual movement.
    //
    // Once approved, uncomment the block below and replace the
    //     AssignTargetBin(..., TargetType::HighBay)
    // call in RoutePutAwayLine with:
    //     ApplyMinQtyFallbackOrHighBay(WhseActivityLine, TargetType);
    //
    // local procedure ApplyMinQtyFallbackOrHighBay(var WhseActivityLine: Record "Warehouse Activity Line"; TargetType: Enum "Put-Away Target Zone NDPP")
    // var
    //     MainBinContent: Record "Bin Content";
    //     SplitLine: Record "Warehouse Activity Line";
    //     ExistingQty: Decimal;
    //     MinBaseQty: Decimal;
    //     QtyToTopUp: Decimal;
    // begin
    //     if not TryGetMainBinContent(WhseActivityLine."Item No.", TargetType, MainBinContent) then begin
    //         AssignTargetBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
    //         exit;
    //     end;
    //
    //     MinBaseQty := MainBinContent."Min. Qty." * MainBinContent."Qty. per Unit of Measure";
    //     if MinBaseQty <= 0 then begin
    //         AssignTargetBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
    //         exit;
    //     end;
    //
    //     ExistingQty := CalcReservedQty(WhseActivityLine."Item No.", TargetType);
    //     QtyToTopUp := MinBaseQty - ExistingQty;
    //
    //     if QtyToTopUp <= 0 then begin
    //         AssignTargetBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
    //         exit;
    //     end;
    //
    //     if QtyToTopUp >= WhseActivityLine."Qty. (Base)" then begin
    //         AssignTargetBin(WhseActivityLine, TargetType);
    //         exit;
    //     end;
    //
    //     // Keep `QtyToTopUp` on the decant face, send the rest to HighBay via SplitLine.
    //     AssignTargetBin(WhseActivityLine, TargetType);
    //     WhseActivityLine.Validate("Qty. to Handle (Base)", QtyToTopUp);
    //     WhseActivityLine.Modify();
    //
    //     SplitLine.Copy(WhseActivityLine);
    //     G_LineSpacing := true;
    //     WhseActivityLine.SplitLine(SplitLine);
    //     WhseActivityLine.Copy(SplitLine);
    //     G_LineSpacing := false;
    // end;
    // ---------------------------------------------------------------------

    procedure ClearReservedQty()
    begin
        Clear(G_BinContentQty);
    end;

    /// <summary>
    /// Forces a Put-Away line into the High-Bay bin — used for split-line
    /// spillover from HandleBinCapacity.
    /// </summary>
    procedure RoutePutAwayLineAsHighBay(var WhseActivityLine: Record "Warehouse Activity Line")
    begin
        AssignTargetBin(WhseActivityLine, "Put-Away Target Zone NDPP"::HighBay);
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
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        G_BinContentQty: Decimal;
        G_IsExecuting: Boolean;
        G_LineSpacing: Boolean;
}
