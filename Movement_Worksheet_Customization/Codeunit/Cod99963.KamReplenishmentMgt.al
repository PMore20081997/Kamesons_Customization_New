namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.Worksheet;

/// <summary>
/// Facade for movement-worksheet replenishment.
/// The report (and any future page action) delegates here so business logic
/// is in one place and unit-testable. Publishes integration events so other
/// extensions can pre-empt or post-process every line.
/// </summary>
codeunit 99963 "Kam Replenishment Mgt."
{
    Access = Public;
    SingleInstance = true;

    var
        ToteMath: Codeunit "Kam Tote Math";
        SetupLookup: Codeunit "Kam Whse Setup Lookup";
        WhseWkshTemplateName: Code[10];
        WhseWkshName: Code[10];
        PickBulkLocation: Code[10];
        ReceiveLocation: Code[10];
        BulkDecantZone: Code[10];
        GenDecantZone: Code[10];
        HighBayZone: Code[10];
        PickBulkZone: Code[10];
        BulkDecantBin: Code[20];
        GenDecantBin: Code[20];
        DoNotFillQtytoHandle: Boolean;
        NextLineNo: Integer;
        LinesInserted: Integer;
        ProcessedFlowrackItems: List of [Code[20]];
        PickBulkLocNotSetErr: Label 'The PICK BULK Location is not set. Configure it in Warehouse Setup (MAIN Warehouse) or enter it on the request page.';
        ReceiveLocNotSetErr: Label 'The BULK Location is not set. Configure the RECEIVE Warehouse in Warehouse Setup.';
        BulkDecantZoneNotFoundErr: Label 'No zone with the Bulk flag was found in the BULK Location.';
        HighBayZoneNotFoundErr: Label 'No zone with the High Bay flag was found in the BULK Location.';
        PickBulkZoneNotFoundErr: Label 'No zone with the Bulk flag was found in the PICK BULK Location.';
        GenDecantZoneNotFoundErr: Label 'No zone with the General Decant flag was found in the BULK Location.';

    /// <summary>
    /// Captures request parameters, resolves all warehouse zones, and primes the
    /// next worksheet line number. Must be called once before the first
    /// ProcessBinContent call (typically in OnPreDataItem).
    /// </summary>
    procedure Initialize(WkshTemplate: Code[10]; Wksh: Code[10]; PickBulkLoc: Code[10]; SkipQtyToHandle: Boolean)
    begin
        WhseWkshTemplateName := WkshTemplate;
        WhseWkshName := Wksh;
        DoNotFillQtytoHandle := SkipQtyToHandle;

        PickBulkLocation := PickBulkLoc;
        if PickBulkLocation = '' then
            PickBulkLocation := SetupLookup.GetMainLocation();
        ReceiveLocation := SetupLookup.GetReceiveLocation();

        BulkDecantZone := SetupLookup.GetBulkZone(ReceiveLocation);
        GenDecantZone := SetupLookup.GetReceiveFlowrackZone(ReceiveLocation);
        HighBayZone := SetupLookup.GetHighBayZone(ReceiveLocation);
        PickBulkZone := SetupLookup.GetBulkZone(PickBulkLocation);

        if PickBulkLocation = '' then
            Error(PickBulkLocNotSetErr);
        if ReceiveLocation = '' then
            Error(ReceiveLocNotSetErr);
        if BulkDecantZone = '' then
            Error(BulkDecantZoneNotFoundErr);
        if HighBayZone = '' then
            Error(HighBayZoneNotFoundErr);
        if PickBulkZone = '' then
            Error(PickBulkZoneNotFoundErr);
        if GenDecantZone = '' then
            Error(GenDecantZoneNotFoundErr);

        // RECEIVE holds exactly one bin per routing type. Resolve them once;
        // GetBulkBin / GetFlowrackBin throw if their flagged bin is missing.
        BulkDecantBin := SetupLookup.GetBulkBin(ReceiveLocation);
        GenDecantBin := SetupLookup.GetFlowrackBin(ReceiveLocation);

        SetNextLineNo();
        LinesInserted := 0;
        Clear(ProcessedFlowrackItems);
    end;

    /// <summary>
    /// Dispatcher entry point. Skips bins not in PICK BULK Location; routes to the
    /// qty-based or tote-based processor based on Item.Routing Type.
    /// </summary>
    procedure ProcessBinContent(var BinContent: Record "Bin Content")
    var
        Item: Record Item;
        ToZoneCode: Code[10];
        MainGenDecantZone: Code[10];
        IsHandled: Boolean;
    begin
        OnBeforeProcessBinContent(BinContent, IsHandled);
        if IsHandled then
            exit;

        if BinContent."Location Code" <> PickBulkLocation then
            exit;

        Item.SetLoadFields("Routing Type");
        if not Item.Get(BinContent."Item No.") then
            exit;

        case Item."Routing Type" of
            Item."Routing Type"::BULK:
                begin
                    if BinContent."Zone Code" <> PickBulkZone then
                        exit;
                    ToZoneCode := BulkDecantZone;
                end;
            Item."Routing Type"::Flowrack,
            Item."Routing Type"::"Static":
                begin
                    MainGenDecantZone := SetupLookup.GetReceiveFlowrackZone(PickBulkLocation);
                    if BinContent."Zone Code" <> MainGenDecantZone then
                        exit;
                    ToZoneCode := GenDecantZone;
                end;
            else
                exit;
        end;

        case Item."Routing Type" of
            Item."Routing Type"::BULK,
            Item."Routing Type"::"Static":
                ProcessBulkItem(BinContent, ToZoneCode);
            Item."Routing Type"::Flowrack:
                begin
                    // Flowrack items can occupy multiple PICK BULK bins. Aggregate the need
                    // across all those bins and process the item once per run.
                    if ProcessedFlowrackItems.Contains(BinContent."Item No.") then
                        exit;
                    ProcessedFlowrackItems.Add(BinContent."Item No.");
                    ProcessFlowrackItem(BinContent, ToZoneCode);
                end;
        end;

        OnAfterProcessBinContent(BinContent);
    end;

    procedure GetLinesInserted(): Integer
    begin
        exit(LinesInserted);
    end;

    local procedure ProcessBulkItem(var BinContent: Record "Bin Content"; ToZoneCode: Code[10])
    var
        FEFOQuery: Query "FEFO Whse Entry HIGHBAY";
        PickBulkAvailBase: Decimal;
        MinQtyBase: Decimal;
        MaxQtyBase: Decimal;
        NeedQtyBase: Decimal;
        LotAvailBase: Decimal;
        PendingLotBase: Decimal;
        MoveQtyBase: Decimal;
        DestBin: Code[20];
    begin
        // Trigger: PICK BULK bin available qty < PICK BULK Min. Qty.
        PickBulkAvailBase := BinContent.CalcQtyAvailToTake(0);
        MinQtyBase := BinContent."Min. Qty." * BinContent."Qty. per Unit of Measure";
        if PickBulkAvailBase >= MinQtyBase then
            exit;

        MaxQtyBase := BinContent."Max. Qty." * BinContent."Qty. per Unit of Measure";
        if MaxQtyBase <= 0 then
            exit;

        NeedQtyBase :=
            MaxQtyBase
            - PickBulkAvailBase
            - ToteMath.GetDestinationZoneAvailQty(ReceiveLocation, ToZoneCode, BinContent."Item No.")
            - ToteMath.GetActivityQtyToDestination(ReceiveLocation, ToZoneCode, BinContent."Item No.")
            - ToteMath.GetQtyAlreadyInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, HighBayZone, ToZoneCode, BinContent."Item No.");
        if NeedQtyBase <= 0 then
            exit;

        // RECEIVE holds one bin per routing type — resolved once in Initialize.
        if ToZoneCode = BulkDecantZone then
            DestBin := BulkDecantBin
        else
            DestBin := GenDecantBin;

        // FEFO from HIGHBAY, partial-lot allowed; placement is into the single Receive bin.
        FEFOQuery.SetFilter(FEFOQuery.Location_Code, '%1', ReceiveLocation);
        FEFOQuery.SetFilter(FEFOQuery.Zone_Code, '%1', HighBayZone);
        FEFOQuery.SetFilter(FEFOQuery.Item_No_, '%1', BinContent."Item No.");
        FEFOQuery.SetFilter(FEFOQuery.Quantity_Base, '>%1', 0);
        FEFOQuery.Open();
        while FEFOQuery.Read() and (NeedQtyBase > 0) do begin
            LotAvailBase := FEFOQuery.Quantity_Base;
            PendingLotBase := ToteMath.GetLotQtyAlreadyInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, BinContent."Item No.", FEFOQuery.Lot_No_);
            LotAvailBase -= PendingLotBase;

            if LotAvailBase > 0 then begin
                if LotAvailBase >= NeedQtyBase then
                    MoveQtyBase := NeedQtyBase
                else
                    MoveQtyBase := LotAvailBase;

                InsertMovementWkshLine(
                    BinContent, FEFOQuery.Lot_No_, FEFOQuery.Expiration_Date,
                    FEFOQuery.Unit_of_Measure_Code, FEFOQuery.Qty_per_Unit_of_Measure,
                    MoveQtyBase, ToZoneCode, DestBin, FEFOQuery.Bin_Code,
                    FEFOQuery.Manufacturer_Code, FEFOQuery.Package_No_);

                NeedQtyBase -= MoveQtyBase;
            end;
        end;
        FEFOQuery.Close();
    end;

    local procedure ProcessFlowrackItem(var BinContent: Record "Bin Content"; ToZoneCode: Code[10])
    var
        BinContentIter: Record "Bin Content";
        FEFOQuery: Query "FEFO Whse Entry HIGHBAY";
        BinAvailBase: Decimal;
        BinMinQtyBase: Decimal;
        BinGapTotes: Integer;
        QtyPerTote: Decimal;
        LotAvailQtyBase: Decimal;
        PendingLotQtyBase: Decimal;
        MoveQtyBase: Decimal;
        DestTotes: Integer;
        ActivityTotes: Integer;
        PendingTotes: Integer;
        TotesNeededForItem: Integer;
        TotesAvail: Integer;
        TotesToMove: Integer;
    begin
        // Per-bin gap: each Flowrack bin contributes to the need ONLY if its current
        // avail is below its own Min. Qty. — full bins are excluded. Sum the gaps
        // (in tote count) to size what we stage from HIGHBAY.
        BinContentIter.SetRange("Location Code", PickBulkLocation);
        BinContentIter.SetRange("Item No.", BinContent."Item No.");
        if BinContentIter.FindSet() then
            repeat
                BinContentIter.CalcFields(Flowrack);
                if BinContentIter.Flowrack then begin
                    BinAvailBase := BinContentIter.CalcQtyAvailToTake(0);
                    BinMinQtyBase := BinContentIter."Min. Qty." * BinContentIter."Qty. per Unit of Measure";
                    if BinAvailBase < BinMinQtyBase then begin
                        BinGapTotes := BinContentIter."Number of Totes in a Bin"
                                     - ToteMath.GetFlowrackTotes(BinContentIter);
                        if BinGapTotes > 0 then
                            TotesNeededForItem += BinGapTotes;
                    end;
                end;
            until BinContentIter.Next() = 0;

        if TotesNeededForItem = 0 then
            exit;

        DestTotes := ToteMath.GetDestinationTotes(ReceiveLocation, ToZoneCode, BinContent."Item No.");
        ActivityTotes := ToteMath.GetActivityTotesToDestination(ReceiveLocation, ToZoneCode, BinContent."Item No.");
        PendingTotes := ToteMath.CountPendingTotesInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, HighBayZone, ToZoneCode, BinContent."Item No.");
        TotesNeededForItem -= DestTotes;
        TotesNeededForItem -= ActivityTotes;
        TotesNeededForItem -= PendingTotes;
        if TotesNeededForItem <= 0 then
            exit;

        // FEFO from HIGHBAY — whole totes only, per manufacturer's Qty per Tote.
        FEFOQuery.SetFilter(FEFOQuery.Location_Code, '%1', ReceiveLocation);
        FEFOQuery.SetFilter(FEFOQuery.Zone_Code, '%1', HighBayZone);
        FEFOQuery.SetFilter(FEFOQuery.Item_No_, '%1', BinContent."Item No.");
        FEFOQuery.SetFilter(FEFOQuery.Quantity_Base, '>%1', 0);
        FEFOQuery.Open();
        while FEFOQuery.Read() and (TotesNeededForItem > 0) do begin
            QtyPerTote := ToteMath.GetQtyPerTote(BinContent."Item No.", FEFOQuery.Manufacturer_Code);
            if QtyPerTote > 0 then begin
                LotAvailQtyBase := FEFOQuery.Quantity_Base;
                PendingLotQtyBase := ToteMath.GetLotQtyAlreadyInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, BinContent."Item No.", FEFOQuery.Lot_No_);
                LotAvailQtyBase -= PendingLotQtyBase;

                if LotAvailQtyBase >= QtyPerTote then begin
                    TotesAvail := Round(LotAvailQtyBase / QtyPerTote, 1, '>');
                    if TotesAvail > TotesNeededForItem then
                        TotesToMove := TotesNeededForItem
                    else
                        TotesToMove := TotesAvail;

                    if TotesToMove > 0 then begin
                        MoveQtyBase := TotesToMove * QtyPerTote;
                        InsertMovementWkshLine(
                            BinContent, FEFOQuery.Lot_No_, FEFOQuery.Expiration_Date,
                            FEFOQuery.Unit_of_Measure_Code, FEFOQuery.Qty_per_Unit_of_Measure,
                            MoveQtyBase, ToZoneCode, GenDecantBin, FEFOQuery.Bin_Code,
                            FEFOQuery.Manufacturer_Code, FEFOQuery.Package_No_);

                        TotesNeededForItem -= TotesToMove;
                    end;
                end;
            end;
        end;
        FEFOQuery.Close();
    end;

    local procedure InsertMovementWkshLine(var BinContent: Record "Bin Content"; LotNo: Code[50]; ExpirationDate: Date; UoMCode: Code[10]; QtyPerUoM: Decimal; MoveQtyBase: Decimal; ToZoneCode: Code[10]; ToBinCode: Code[20]; FromBinCode: Code[20]; ManufacturerCode: Code[10]; PackageNo: Code[50])
    var
        WhseWkshLine: Record "Whse. Worksheet Line";
        Item: Record Item;
    begin
        WhseWkshLine.Init();
        WhseWkshLine."Worksheet Template Name" := WhseWkshTemplateName;
        WhseWkshLine.Name := WhseWkshName;
        WhseWkshLine."Location Code" := ReceiveLocation;
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

    local procedure InsertWhseItemTrackingLine(var WhseWkshLine: Record "Whse. Worksheet Line"; LotNo: Code[50]; ExpirationDate: Date; QtyBase: Decimal; ManufacturerCode: Code[10]; PackageNo: Code[50])
    var
        WhseItemTrackingLine: Record "Whse. Item Tracking Line";
        NextEntryNo: Integer;
    begin
        if LotNo = '' then
            exit;

        WhseItemTrackingLine.Reset();
        if WhseItemTrackingLine.FindLast() then
            NextEntryNo := WhseItemTrackingLine."Entry No." + 1
        else
            NextEntryNo := 1;

        WhseItemTrackingLine.Init();
        WhseItemTrackingLine."Entry No." := NextEntryNo;
        WhseItemTrackingLine."Source Type" := DATABASE::"Whse. Worksheet Line";
        WhseItemTrackingLine."Source Subtype" := 0;
        WhseItemTrackingLine."Source ID" := WhseWkshLine.Name;
        WhseItemTrackingLine."Source Batch Name" := WhseWkshLine."Worksheet Template Name";
        WhseItemTrackingLine."Source Prod. Order Line" := 0;
        WhseItemTrackingLine."Source Ref. No." := WhseWkshLine."Line No.";

        WhseItemTrackingLine."Item No." := WhseWkshLine."Item No.";
        WhseItemTrackingLine."Variant Code" := WhseWkshLine."Variant Code";
        WhseItemTrackingLine."Location Code" := WhseWkshLine."Location Code";

        WhseItemTrackingLine."Lot No." := LotNo;
        WhseItemTrackingLine."Expiration Date" := ExpirationDate;
        WhseItemTrackingLine."Package No." := PackageNo;
        WhseItemTrackingLine."Manufacturer Code" := ManufacturerCode;

        WhseItemTrackingLine."Qty. per Unit of Measure" := WhseWkshLine."Qty. per Unit of Measure";
        WhseItemTrackingLine."Quantity (Base)" := QtyBase;
        WhseItemTrackingLine."Qty. to Handle (Base)" := QtyBase;

        WhseItemTrackingLine.Insert(true);
    end;

    local procedure SetNextLineNo()
    var
        WhseWkshLine: Record "Whse. Worksheet Line";
    begin
        WhseWkshLine.SetRange("Worksheet Template Name", WhseWkshTemplateName);
        WhseWkshLine.SetRange(Name, WhseWkshName);
        WhseWkshLine.SetRange("Location Code", ReceiveLocation);
        if WhseWkshLine.FindLast() then
            NextLineNo := WhseWkshLine."Line No." + 10000
        else
            NextLineNo := 10000;
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
