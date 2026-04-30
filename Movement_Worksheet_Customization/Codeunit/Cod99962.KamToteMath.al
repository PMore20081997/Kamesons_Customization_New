namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.Worksheet;

/// <summary>
/// Pure tote-arithmetic helpers. No record writes — only reads + math.
/// Every method here is unit-testable without the worksheet context;
/// hand it filtered records, get a number back. Same for FEFO selection
/// and pending calculations.
/// </summary>
codeunit 99962 "Kam Tote Math"
{
    Access = Public;

    /// <summary>
    /// Whole totes currently sitting in a PICK BULK bin, summed across manufacturers.
    /// Partial-tote remainders are dropped (whole-tote handling rule).
    /// </summary>
    procedure CountTotesInPickBulkBin(BinContent: Record "Bin Content"): Integer
    var
        WhseEntryQry: Query Warehouse_Entry_Main;
        QtyPerTote: Decimal;
        Totes: Integer;
    begin
        WhseEntryQry.SetFilter(WhseEntryQry.Item_No_, '=%1', BinContent."Item No.");
        WhseEntryQry.SetFilter(WhseEntryQry.Location_Code, '=%1', BinContent."Location Code");
        WhseEntryQry.SetFilter(WhseEntryQry.Zone_Code, '=%1', BinContent."Zone Code");
        WhseEntryQry.SetFilter(WhseEntryQry.Bin_Code, '=%1', BinContent."Bin Code");
        WhseEntryQry.SetFilter(WhseEntryQry.Qty___Base_, '>%1', 0);
        WhseEntryQry.Open();
        while WhseEntryQry.Read() do begin
            QtyPerTote := GetQtyPerTote(BinContent."Item No.", WhseEntryQry.Manufacturer_Code);
            if (QtyPerTote > 0) and (WhseEntryQry.Qty___Base_ >= QtyPerTote) then
                Totes += Round(WhseEntryQry.Qty___Base_ / QtyPerTote, 1, '<');
        end;
        WhseEntryQry.Close();
        exit(Totes);
    end;

    procedure GetQtyPerTote(ItemNo: Code[20]; ManufacturerCode: Code[50]): Decimal
    var
        ItemMfr: Record "Item Manufacturer Table";
    begin
        if (ItemNo = '') or (ManufacturerCode = '') then
            exit(0);
        if ItemMfr.Get(ItemNo, ManufacturerCode) then
            exit(ItemMfr."Qty per Tote");
        exit(0);
    end;

    /// <summary>
    /// Whole totes already planned in the open Movement Worksheet for an item & destination zone.
    /// Used to avoid double-replenishing within the same calculation run.
    /// </summary>
    procedure CountPendingTotesInWorksheet(WkshTemplate: Code[10]; WkshName: Code[10]; LocationCode: Code[20]; FromZone: Code[10]; ToZone: Code[10]; ItemNo: Code[20]): Integer
    var
        ItemMfr: Record "Item Manufacturer Table";
        WhseWkshLine: Record "Whse. Worksheet Line";
        WhseItemTrack: Record "Whse. Item Tracking Line";
        MfgQtyBase: Decimal;
        Totes: Integer;
    begin
        ItemMfr.SetRange("Item No", ItemNo);
        ItemMfr.SetFilter("Qty per Tote", '>%1', 0);
        if not ItemMfr.FindSet() then
            exit(0);

        repeat
            MfgQtyBase := 0;
            WhseWkshLine.SetCurrentKey("Worksheet Template Name", Name, "Location Code");
            WhseWkshLine.SetRange("Worksheet Template Name", WkshTemplate);
            WhseWkshLine.SetRange(Name, WkshName);
            WhseWkshLine.SetRange("Location Code", LocationCode);
            WhseWkshLine.SetRange("From Zone Code", FromZone);
            WhseWkshLine.SetRange("To Zone Code", ToZone);
            WhseWkshLine.SetRange("Item No.", ItemNo);
            if WhseWkshLine.FindSet() then
                repeat
                    WhseItemTrack.Reset();
                    WhseItemTrack.SetRange("Source Type", Database::"Whse. Worksheet Line");
                    WhseItemTrack.SetRange("Source ID", WhseWkshLine.Name);
                    WhseItemTrack.SetRange("Source Batch Name", WhseWkshLine."Worksheet Template Name");
                    WhseItemTrack.SetRange("Source Ref. No.", WhseWkshLine."Line No.");
                    WhseItemTrack.SetRange("Item No.", ItemNo);
                    WhseItemTrack.SetRange("Manufacture Code", ItemMfr."Manufacturer Code");
                    WhseItemTrack.CalcSums("Quantity (Base)");
                    MfgQtyBase += WhseItemTrack."Quantity (Base)";
                until WhseWkshLine.Next() = 0;

            if MfgQtyBase >= ItemMfr."Qty per Tote" then
                Totes += Round(MfgQtyBase / ItemMfr."Qty per Tote", 1, '<');
        until ItemMfr.Next() = 0;
        exit(Totes);
    end;

    /// <summary>
    /// Quantity already planned in the open worksheet for an item & destination zone (in base units).
    /// </summary>
    procedure GetQtyAlreadyInWorksheet(WkshTemplate: Code[10]; WkshName: Code[10]; LocationCode: Code[20]; FromZone: Code[10]; ToZone: Code[10]; ItemNo: Code[20]): Decimal
    var
        WhseWkshLine: Record "Whse. Worksheet Line";
    begin
        WhseWkshLine.SetCurrentKey("Worksheet Template Name", Name, "Location Code");
        WhseWkshLine.SetRange("Worksheet Template Name", WkshTemplate);
        WhseWkshLine.SetRange(Name, WkshName);
        WhseWkshLine.SetRange("Location Code", LocationCode);
        WhseWkshLine.SetRange("From Zone Code", FromZone);
        WhseWkshLine.SetRange("To Zone Code", ToZone);
        WhseWkshLine.SetRange("Item No.", ItemNo);
        WhseWkshLine.CalcSums("Qty. (Base)");
        exit(WhseWkshLine."Qty. (Base)");
    end;

    procedure GetLotQtyAlreadyInWorksheet(WkshTemplate: Code[10]; WkshName: Code[10]; LocationCode: Code[20]; ItemNo: Code[20]; LotNo: Code[50]): Decimal
    var
        WhseItemTrack: Record "Whse. Item Tracking Line";
    begin
        WhseItemTrack.SetRange("Source Type", Database::"Whse. Worksheet Line");
        WhseItemTrack.SetRange("Source ID", WkshName);
        WhseItemTrack.SetRange("Source Batch Name", WkshTemplate);
        WhseItemTrack.SetRange("Location Code", LocationCode);
        WhseItemTrack.SetRange("Item No.", ItemNo);
        WhseItemTrack.SetRange("Lot No.", LotNo);
        WhseItemTrack.CalcSums("Quantity (Base)");
        exit(WhseItemTrack."Quantity (Base)");
    end;

    /// <summary>
    /// Total quantity available in a destination zone for an item, across all bins.
    /// </summary>
    procedure GetDestinationZoneAvailQty(LocationCode: Code[10]; ZoneCode: Code[10]; ItemNo: Code[20]): Decimal
    var
        BinContent: Record "Bin Content";
        Total: Decimal;
    begin
        BinContent.SetCurrentKey("Location Code", "Zone Code", "Item No.");
        BinContent.SetRange("Location Code", LocationCode);
        BinContent.SetRange("Zone Code", ZoneCode);
        BinContent.SetRange("Item No.", ItemNo);
        if BinContent.FindSet() then
            repeat
                Total += BinContent.CalcQtyAvailToTake(0);
            until BinContent.Next() = 0;
        exit(Total);
    end;

    /// <summary>Look up the bin code holding the item in a given zone.</summary>
    procedure GetBinForItemInZone(LocationCode: Code[10]; ZoneCode: Code[10]; ItemNo: Code[20]): Code[20]
    var
        BinContent: Record "Bin Content";
    begin
        BinContent.SetCurrentKey("Location Code", "Zone Code", "Item No.");
        BinContent.SetRange("Location Code", LocationCode);
        BinContent.SetRange("Zone Code", ZoneCode);
        BinContent.SetRange("Item No.", ItemNo);
        if BinContent.FindFirst() then
            exit(BinContent."Bin Code");
        exit('');
    end;
}
