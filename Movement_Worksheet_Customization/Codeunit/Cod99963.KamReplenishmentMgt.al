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
        BulkDecantBin: Code[20];
        GenDecantBin: Code[20];
        StaticDecantBin: Code[20];
        HighBayBin: Code[20];
        PickBulkBin: Code[20];
        DoNotFillQtytoHandle: Boolean;
        NextLineNo: Integer;
        LinesInserted: Integer;
        ProcessedFlowrackItems: List of [Code[20]];
        PickBulkLocNotSetErr: Label 'The PICK BULK Location is not set. Configure it in Warehouse Setup (MAIN Warehouse) or enter it on the request page.';
        ReceiveLocNotSetErr: Label 'The BULK Location is not set. Configure the RECEIVE Warehouse in Warehouse Setup.';
        BulkDecantBinNotFoundErr: Label 'No bin with the Bulk flag was found in the BULK Location.';
        HighBayBinNotFoundErr: Label 'No bin with the High Bay flag was found in the BULK Location.';
        PickBulkBinNotFoundErr: Label 'No bin with the Bulk flag was found in the PICK BULK Location.';
        GenDecantBinNotFoundErr: Label 'No bin with the Flowrack flag was found in the BULK Location.';
        StaticBinNotFoundErr: Label 'No bin with the Static flag was found in the BULK Location.';

    /// <summary>
    /// Captures request parameters, resolves all warehouse bins (by Boolean
    /// flag on the Bin record), and primes the next worksheet line number.
    /// Must be called once before the first ProcessBinContent call (typically
    /// in OnPreDataItem).
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

        if PickBulkLocation = '' then
            Error(PickBulkLocNotSetErr);
        if ReceiveLocation = '' then
            Error(ReceiveLocNotSetErr);

        // RECEIVE holds exactly one bin per routing type. PICK BULK has one
        // BULK bin. All resolved by Boolean flag on Bin. Get* helpers throw
        // if their flagged bin is missing — the defensive '' checks below
        // are belt-and-braces only.
        BulkDecantBin := SetupLookup.GetBulkBin(ReceiveLocation);
        GenDecantBin := SetupLookup.GetFlowrackBin(ReceiveLocation);
        StaticDecantBin := SetupLookup.GetStaticBin(ReceiveLocation);
        HighBayBin := SetupLookup.GetHighBayBin(ReceiveLocation);
        PickBulkBin := SetupLookup.GetBulkBin(PickBulkLocation);

        if BulkDecantBin = '' then
            Error(BulkDecantBinNotFoundErr);
        if HighBayBin = '' then
            Error(HighBayBinNotFoundErr);
        if PickBulkBin = '' then
            Error(PickBulkBinNotFoundErr);
        if GenDecantBin = '' then
            Error(GenDecantBinNotFoundErr);
        if StaticDecantBin = '' then
            Error(StaticBinNotFoundErr);

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
        Bin: Record Bin;
        ToBinCode: Code[20];
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

        // MAIN may have multiple bins of each routing type for the same item
        // (e.g. several Flowrack bins, several Static bins). Match by the bin's
        // Boolean flag on the Bin record, not by a single resolved Bin Code.
        if not Bin.Get(BinContent."Location Code", BinContent."Bin Code") then
            exit;

        case Item."Routing Type" of
            Item."Routing Type"::BULK:
                begin
                    if not Bin.Bulk then
                        exit;
                    ToBinCode := BulkDecantBin;
                end;
            Item."Routing Type"::Flowrack:
                begin
                    if not Bin.Flowrack then
                        exit;
                    ToBinCode := GenDecantBin;
                end;
            Item."Routing Type"::"Static":
                begin
                    if not Bin."Static" then
                        exit;
                    ToBinCode := StaticDecantBin;
                end;
            else
                exit;
        end;

        case Item."Routing Type" of
            Item."Routing Type"::BULK,
            Item."Routing Type"::"Static":
                ProcessBulkItem(BinContent, ToBinCode);
            Item."Routing Type"::Flowrack:
                begin
                    // Flowrack items can occupy multiple PICK BULK bins. Aggregate the need
                    // across all those bins and process the item once per run.
                    if ProcessedFlowrackItems.Contains(BinContent."Item No.") then
                        exit;
                    ProcessedFlowrackItems.Add(BinContent."Item No.");
                    ProcessFlowrackItem(BinContent, ToBinCode);
                end;
        end;

        OnAfterProcessBinContent(BinContent);
    end;

    procedure GetLinesInserted(): Integer
    begin
        exit(LinesInserted);
    end;

    local procedure ProcessBulkItem(var BinContent: Record "Bin Content"; ToBinCode: Code[20])
    var
        FEFOQuery: Query "FEFO Whse Entry HIGHBAY";
        PickBulkAvailBase: Decimal;
        MinQtyBase: Decimal;
        MaxQtyBase: Decimal;
        NeedQtyBase: Decimal;
        LotAvailBase: Decimal;
        PendingLotBase: Decimal;
        MoveQtyBase: Decimal;
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
            - ToteMath.GetDestinationBinAvailQty(ReceiveLocation, ToBinCode, BinContent."Item No.")
            - ToteMath.GetActivityQtyToDestination(ReceiveLocation, ToBinCode, BinContent."Item No.")
            - ToteMath.GetQtyAlreadyInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, HighBayBin, ToBinCode, BinContent."Item No.");
        if NeedQtyBase <= 0 then
            exit;

        // FEFO from HIGHBAY, partial-lot allowed; placement is into the single Receive bin (ToBinCode).
        FEFOQuery.SetFilter(FEFOQuery.Location_Code, '%1', ReceiveLocation);
        FEFOQuery.SetFilter(FEFOQuery.Bin_Code, '%1', HighBayBin);
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
                    MoveQtyBase, ToBinCode, FEFOQuery.Bin_Code,
                    FEFOQuery.Manufacturer_Code, FEFOQuery.Package_No_);

                NeedQtyBase -= MoveQtyBase;
            end;
        end;
        FEFOQuery.Close();
    end;

    local procedure ProcessFlowrackItem(var BinContent: Record "Bin Content"; ToBinCode: Code[20])
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

        DestTotes := ToteMath.GetDestinationTotes(ReceiveLocation, ToBinCode, BinContent."Item No.");
        ActivityTotes := ToteMath.GetActivityTotesToDestination(ReceiveLocation, ToBinCode, BinContent."Item No.");
        PendingTotes := ToteMath.CountPendingTotesInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, HighBayBin, ToBinCode, BinContent."Item No.");
        TotesNeededForItem -= DestTotes;
        TotesNeededForItem -= ActivityTotes;
        TotesNeededForItem -= PendingTotes;
        if TotesNeededForItem <= 0 then
            exit;

        // FEFO from HIGHBAY — whole totes only, per manufacturer's Qty per Tote.
        FEFOQuery.SetFilter(FEFOQuery.Location_Code, '%1', ReceiveLocation);
        FEFOQuery.SetFilter(FEFOQuery.Bin_Code, '%1', HighBayBin);
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
                            MoveQtyBase, ToBinCode, FEFOQuery.Bin_Code,
                            FEFOQuery.Manufacturer_Code, FEFOQuery.Package_No_);

                        TotesNeededForItem -= TotesToMove;
                    end;
                end;
            end;
        end;
        FEFOQuery.Close();
    end;

    local procedure InsertMovementWkshLine(var BinContent: Record "Bin Content"; LotNo: Code[50]; ExpirationDate: Date; UoMCode: Code[10]; QtyPerUoM: Decimal; MoveQtyBase: Decimal; ToBinCode: Code[20]; FromBinCode: Code[20]; ManufacturerCode: Code[10]; PackageNo: Code[50])
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

        // Bin codes set via Validate so BC auto-derives the From/To Zone Code
        // from the Bin record. We never look up zones from setup ourselves.
        WhseWkshLine.Validate("From Bin Code", FromBinCode);
        WhseWkshLine.Validate("To Bin Code", ToBinCode);

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
