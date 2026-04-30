namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.Worksheet;

/// <summary>
/// Facade for movement-worksheet replenishment.
/// Page actions and the report dataitem trigger delegate here so business logic is
/// in one place and unit-testable. Publishes integration events so other extensions
/// can pre-empt or post-process every line.
/// </summary>
codeunit 99963 "Kam Replenishment Mgt."
{
    Access = Public;

    var
        WhseSetup: Codeunit "Kam Whse Setup Lookup";
        ToteMath: Codeunit "Kam Tote Math";
        WkshTemplateName: Code[10];
        WkshName: Code[10];
        BulkLocation: Code[10];
        PickBulkLocation: Code[10];
        BulkDecantZone: Code[10];
        HighBayZone: Code[10];
        PickBulkZone: Code[10];
        DoNotFillQtytoHandle: Boolean;
        NextLineNo: Integer;
        LinesInserted: Integer;

    procedure Initialize(WkshTemplate: Code[10]; Wksh: Code[10]; PickBulkLoc: Code[10]; SkipQtyToHandle: Boolean)
    begin
        WkshTemplateName := WkshTemplate;
        WkshName := Wksh;
        PickBulkLocation := PickBulkLoc;
        if PickBulkLocation = '' then
            PickBulkLocation := WhseSetup.GetMainLocation();
        BulkLocation := WhseSetup.GetReceiveLocation();
        BulkDecantZone := WhseSetup.GetBulkZone(BulkLocation);
        HighBayZone := WhseSetup.GetHighBayZone(BulkLocation);
        PickBulkZone := WhseSetup.GetBulkZone(PickBulkLocation);
        DoNotFillQtytoHandle := SkipQtyToHandle;
        SetNextLineNo();
        LinesInserted := 0;
    end;

    procedure GetLinesInserted(): Integer
    begin
        exit(LinesInserted);
    end;

    procedure ProcessBinContent(var BinContent: Record "Bin Content")
    var
        Item: Record Item;
        ToZoneCode: Code[10];
        ToBinCode: Code[20];
        IsHandled: Boolean;
    begin
        OnBeforeProcessBinContent(BinContent, IsHandled);
        if IsHandled then
            exit;

        if BinContent."Location Code" <> PickBulkLocation then
            exit;

        Item.SetLoadFields(BULK);
        if not Item.Get(BinContent."Item No.") then
            exit;

        if Item.BULK then begin
            if BinContent."Zone Code" <> PickBulkZone then
                exit;
            ToZoneCode := BulkDecantZone;
        end else begin
            if not WhseSetup.TryGetGenDecantZone(PickBulkLocation, ToZoneCode) then
                exit;
            if BinContent."Zone Code" <> ToZoneCode then
                exit;
            ToZoneCode := WhseSetup.GetGenDecantZone(BulkLocation);
        end;

        ToBinCode := ToteMath.GetBinForItemInZone(BulkLocation, ToZoneCode, BinContent."Item No.");
        if ToBinCode = '' then
            exit;

        if Item.BULK then
            ProcessBulkItem(BinContent, ToZoneCode, ToBinCode)
        else
            ProcessNonBulkItem(BinContent, ToZoneCode, ToBinCode);

        OnAfterProcessBinContent(BinContent);
    end;

    local procedure ProcessBulkItem(var BinContent: Record "Bin Content"; ToZoneCode: Code[10]; ToBinCode: Code[20])
    var
        FEFOQry: Query "FEFO Whse Entry HIGHBAY";
        AvailBase: Decimal;
        MinBase: Decimal;
        MaxBase: Decimal;
        NeedBase: Decimal;
        LotAvailBase: Decimal;
        PendingLotBase: Decimal;
        MoveBase: Decimal;
    begin
        AvailBase := BinContent.CalcQtyAvailToTake(0);
        MinBase := BinContent."Min. Qty." * BinContent."Qty. per Unit of Measure";
        if AvailBase >= MinBase then
            exit;

        MaxBase := BinContent."Max. Qty." * BinContent."Qty. per Unit of Measure";
        if MaxBase <= 0 then
            exit;

        NeedBase := MaxBase - ToteMath.GetDestinationZoneAvailQty(BulkLocation, ToZoneCode, BinContent."Item No.");
        if NeedBase <= 0 then
            exit;

        NeedBase -= ToteMath.GetQtyAlreadyInWorksheet(WkshTemplateName, WkshName, BulkLocation, HighBayZone, ToZoneCode, BinContent."Item No.");
        if NeedBase <= 0 then
            exit;

        FEFOQry.SetFilter(FEFOQry.Location_Code, '=%1', BulkLocation);
        FEFOQry.SetFilter(FEFOQry.Zone_Code, '=%1', HighBayZone);
        FEFOQry.SetFilter(FEFOQry.Item_No_, '=%1', BinContent."Item No.");
        FEFOQry.SetFilter(FEFOQry.Quantity_Base, '>%1', 0);
        FEFOQry.Open();
        while FEFOQry.Read() and (NeedBase > 0) do begin
            LotAvailBase := FEFOQry.Quantity_Base;
            PendingLotBase := ToteMath.GetLotQtyAlreadyInWorksheet(WkshTemplateName, WkshName, BulkLocation, BinContent."Item No.", FEFOQry.Lot_No_);
            LotAvailBase -= PendingLotBase;

            if LotAvailBase > 0 then begin
                if LotAvailBase >= NeedBase then
                    MoveBase := NeedBase
                else
                    MoveBase := LotAvailBase;

                InsertMovementWkshLine(BinContent, FEFOQry.Lot_No_, FEFOQry.Expiration_Date,
                    FEFOQry.Unit_of_Measure_Code, FEFOQry.Qty_per_Unit_of_Measure, MoveBase,
                    ToZoneCode, ToBinCode, FEFOQry.Bin_Code, FEFOQry.Manufacturer_Code, FEFOQry.Package_No_);

                NeedBase -= MoveBase;
            end;
        end;
        FEFOQry.Close();
    end;

    local procedure ProcessNonBulkItem(var BinContent: Record "Bin Content"; ToZoneCode: Code[10]; ToBinCode: Code[20])
    var
        FEFOQry: Query "FEFO Whse Entry HIGHBAY";
        AvailBase: Decimal;
        MinBase: Decimal;
        QtyPerTote: Decimal;
        LotAvailBase: Decimal;
        PendingLotBase: Decimal;
        MoveBase: Decimal;
        TargetTotes: Integer;
        PickBulkTotes: Integer;
        PendingTotes: Integer;
        TotesNeeded: Integer;
        TotesAvail: Integer;
        TotesToMove: Integer;
    begin
        AvailBase := BinContent.CalcQtyAvailToTake(0);
        MinBase := BinContent."Min. Qty." * BinContent."Qty. per Unit of Measure";
        if AvailBase >= MinBase then
            exit;

        TargetTotes := BinContent."Number of Totes in a Bin";
        if TargetTotes <= 0 then
            exit;

        PickBulkTotes := ToteMath.CountTotesInPickBulkBin(BinContent);
        PendingTotes := ToteMath.CountPendingTotesInWorksheet(WkshTemplateName, WkshName, BulkLocation, HighBayZone, ToZoneCode, BinContent."Item No.");
        TotesNeeded := TargetTotes - PickBulkTotes - PendingTotes;
        if TotesNeeded <= 0 then
            exit;

        FEFOQry.SetFilter(FEFOQry.Location_Code, '=%1', BulkLocation);
        FEFOQry.SetFilter(FEFOQry.Zone_Code, '=%1', HighBayZone);
        FEFOQry.SetFilter(FEFOQry.Item_No_, '=%1', BinContent."Item No.");
        FEFOQry.SetFilter(FEFOQry.Quantity_Base, '>%1', 0);
        FEFOQry.Open();
        while FEFOQry.Read() and (TotesNeeded > 0) do begin
            QtyPerTote := ToteMath.GetQtyPerTote(BinContent."Item No.", FEFOQry.Manufacturer_Code);
            if QtyPerTote > 0 then begin
                LotAvailBase := FEFOQry.Quantity_Base;
                PendingLotBase := ToteMath.GetLotQtyAlreadyInWorksheet(WkshTemplateName, WkshName, BulkLocation, BinContent."Item No.", FEFOQry.Lot_No_);
                LotAvailBase -= PendingLotBase;

                if LotAvailBase >= QtyPerTote then begin
                    TotesAvail := Round(LotAvailBase / QtyPerTote, 1, '<');
                    if TotesAvail > TotesNeeded then
                        TotesToMove := TotesNeeded
                    else
                        TotesToMove := TotesAvail;

                    if TotesToMove > 0 then begin
                        MoveBase := TotesToMove * QtyPerTote;
                        InsertMovementWkshLine(BinContent, FEFOQry.Lot_No_, FEFOQry.Expiration_Date,
                            FEFOQry.Unit_of_Measure_Code, FEFOQry.Qty_per_Unit_of_Measure, MoveBase,
                            ToZoneCode, ToBinCode, FEFOQry.Bin_Code, FEFOQry.Manufacturer_Code, FEFOQry.Package_No_);
                        TotesNeeded -= TotesToMove;
                    end;
                end;
            end;
        end;
        FEFOQry.Close();
    end;

    local procedure SetNextLineNo()
    var
        WhseWkshLine: Record "Whse. Worksheet Line";
    begin
        WhseWkshLine.SetRange("Worksheet Template Name", WkshTemplateName);
        WhseWkshLine.SetRange(Name, WkshName);
        WhseWkshLine.SetRange("Location Code", BulkLocation);
        if WhseWkshLine.FindLast() then
            NextLineNo := WhseWkshLine."Line No." + 10000
        else
            NextLineNo := 10000;
    end;

    local procedure InsertMovementWkshLine(var BinContent: Record "Bin Content"; LotNo: Code[50]; ExpirationDate: Date; UoMCode: Code[10]; QtyPerUoM: Decimal; MoveQtyBase: Decimal; ToZoneCode: Code[10]; ToBinCode: Code[20]; FromBinCode: Code[20]; ManufacturerCode: Code[50]; PackageNo: Code[50])
    var
        WhseWkshLine: Record "Whse. Worksheet Line";
        Item: Record Item;
    begin
        WhseWkshLine.Init();
        WhseWkshLine."Worksheet Template Name" := WkshTemplateName;
        WhseWkshLine.Name := WkshName;
        WhseWkshLine."Location Code" := BulkLocation;
        WhseWkshLine."Line No." := NextLineNo;
        WhseWkshLine.Validate("Item No.", BinContent."Item No.");

        WhseWkshLine."Unit of Measure Code" := UoMCode;
        if QtyPerUoM = 0 then
            QtyPerUoM := BinContent."Qty. per Unit of Measure";
        WhseWkshLine."Qty. per Unit of Measure" := QtyPerUoM;

        WhseWkshLine."From Zone Code" := HighBayZone;
        WhseWkshLine."From Bin Code" := FromBinCode;
        WhseWkshLine."To Zone Code" := ToZoneCode;
        WhseWkshLine."To Bin Code" := ToBinCode;

        WhseWkshLine.Validate(Quantity, MoveQtyBase / QtyPerUoM);
        if not DoNotFillQtytoHandle then
            WhseWkshLine.Validate("Qty. to Handle", MoveQtyBase / QtyPerUoM);

        if Item.Get(BinContent."Item No.") then
            WhseWkshLine.Description := Item.Description;

        WhseWkshLine.Insert(true);

        InsertWhseItemTrackingLine(WhseWkshLine, LotNo, ExpirationDate, MoveQtyBase, ManufacturerCode, PackageNo);

        NextLineNo += 10000;
        LinesInserted += 1;

        OnAfterMovementLineCreated(WhseWkshLine);
    end;

    local procedure InsertWhseItemTrackingLine(var WhseWkshLine: Record "Whse. Worksheet Line"; LotNo: Code[50]; ExpirationDate: Date; QtyBase: Decimal; ManufacturerCode: Code[50]; PackageNo: Code[50])
    var
        WhseItemTrack: Record "Whse. Item Tracking Line";
    begin
        if LotNo = '' then
            exit;

        // Entry No. is AutoIncrement on the standard table — let BC assign it.
        WhseItemTrack.Init();
        WhseItemTrack."Source Type" := Database::"Whse. Worksheet Line";
        WhseItemTrack."Source Subtype" := 0;
        WhseItemTrack."Source ID" := WhseWkshLine.Name;
        WhseItemTrack."Source Batch Name" := WhseWkshLine."Worksheet Template Name";
        WhseItemTrack."Source Prod. Order Line" := 0;
        WhseItemTrack."Source Ref. No." := WhseWkshLine."Line No.";

        WhseItemTrack."Item No." := WhseWkshLine."Item No.";
        WhseItemTrack."Variant Code" := WhseWkshLine."Variant Code";
        WhseItemTrack."Location Code" := WhseWkshLine."Location Code";

        WhseItemTrack."Lot No." := LotNo;
        WhseItemTrack."Expiration Date" := ExpirationDate;
        WhseItemTrack."Package No." := PackageNo;
        WhseItemTrack."Manufacture Code" := ManufacturerCode;

        WhseItemTrack."Qty. per Unit of Measure" := WhseWkshLine."Qty. per Unit of Measure";
        WhseItemTrack."Quantity (Base)" := QtyBase;
        WhseItemTrack."Qty. to Handle (Base)" := QtyBase;

        WhseItemTrack.Insert(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessBinContent(var BinContent: Record "Bin Content"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessBinContent(var BinContent: Record "Bin Content")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterMovementLineCreated(var WhseWkshLine: Record "Whse. Worksheet Line")
    begin
    end;
}
