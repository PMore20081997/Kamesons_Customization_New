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
        DoNotFillQtytoHandle: Boolean;
        NextLineNo: Integer;
        LinesInserted: Integer;
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
        GenDecantZone := SetupLookup.GetDecantZone(ReceiveLocation);
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

        SetNextLineNo();
        LinesInserted := 0;
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
                    MainGenDecantZone := SetupLookup.GetDecantZonefromBinContent(PickBulkLocation, BinContent."Item No.");
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
                ProcessNonBulkItem(BinContent, ToZoneCode);
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
        BinCapacities: Dictionary of [Code[20], Decimal];
        PickBulkAvailBase: Decimal;
        MinQtyBase: Decimal;
        MaxQtyBase: Decimal;
        NeedQtyBase: Decimal;
        LotAvailBase: Decimal;
        PendingLotBase: Decimal;
        MoveQtyBase: Decimal;
        PlacedBase: Decimal;
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

        BuildDestBinCapacities(BinContent."Item No.", ToZoneCode, BinCapacities);
        if BinCapacities.Count() = 0 then
            exit;

        // FEFO from HIGHBAY, partial-lot allowed; placement distributed across destination bins.
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

                PlacedBase := PlaceAcrossDestBins(
                    BinCapacities, MoveQtyBase, BinContent,
                    FEFOQuery.Lot_No_, FEFOQuery.Expiration_Date,
                    FEFOQuery.Unit_of_Measure_Code, FEFOQuery.Qty_per_Unit_of_Measure,
                    ToZoneCode, FEFOQuery.Bin_Code,
                    FEFOQuery.Manufacturer_Code, FEFOQuery.Package_No_);

                NeedQtyBase -= PlacedBase;
                if PlacedBase = 0 then
                    break; // destination zone is full
            end;
        end;
        FEFOQuery.Close();
    end;

    local procedure ProcessNonBulkItem(var BinContent: Record "Bin Content"; ToZoneCode: Code[10])
    var
        FEFOQuery: Query "FEFO Whse Entry HIGHBAY";
        BinCapacities: Dictionary of [Code[20], Decimal];
        PickBulkAvailBase: Decimal;
        MinQtyBase: Decimal;
        QtyPerTote: Decimal;
        LotAvailQtyBase: Decimal;
        PendingLotQtyBase: Decimal;
        MoveQtyBase: Decimal;
        PlacedBase: Decimal;
        TargetTotes: Integer;
        PickBulkTotes: Integer;
        DestTotes: Integer;
        ActivityTotes: Integer;
        PendingTotes: Integer;
        TotesNeeded: Integer;
        TotesAvail: Integer;
        TotesToMove: Integer;
        TotesPlaced: Integer;
    begin
        PickBulkAvailBase := BinContent.CalcQtyAvailToTake(0);
        MinQtyBase := BinContent."Min. Qty." * BinContent."Qty. per Unit of Measure";
        if PickBulkAvailBase >= MinQtyBase then
            exit;

        TargetTotes := BinContent."Number of Totes in a Bin";
        if TargetTotes <= 0 then
            exit;

        PickBulkTotes := ToteMath.GetPickBulkTotes(BinContent);
        DestTotes := ToteMath.GetDestinationTotes(ReceiveLocation, ToZoneCode, BinContent."Item No.");
        ActivityTotes := ToteMath.GetActivityTotesToDestination(ReceiveLocation, ToZoneCode, BinContent."Item No.");
        PendingTotes := ToteMath.CountPendingTotesInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, HighBayZone, ToZoneCode, BinContent."Item No.");
        TotesNeeded := TargetTotes - PickBulkTotes - DestTotes - ActivityTotes - PendingTotes;
        if TotesNeeded <= 0 then
            exit;

        BuildDestBinCapacities(BinContent."Item No.", ToZoneCode, BinCapacities);
        if BinCapacities.Count() = 0 then
            exit;

        // FEFO from HIGHBAY — whole totes only, per manufacturer's Qty per Tote.
        FEFOQuery.SetFilter(FEFOQuery.Location_Code, '%1', ReceiveLocation);
        FEFOQuery.SetFilter(FEFOQuery.Zone_Code, '%1', HighBayZone);
        FEFOQuery.SetFilter(FEFOQuery.Item_No_, '%1', BinContent."Item No.");
        FEFOQuery.SetFilter(FEFOQuery.Quantity_Base, '>%1', 0);
        FEFOQuery.Open();
        while FEFOQuery.Read() and (TotesNeeded > 0) do begin
            QtyPerTote := ToteMath.GetQtyPerTote(BinContent."Item No.", FEFOQuery.Manufacturer_Code);
            if QtyPerTote > 0 then begin
                LotAvailQtyBase := FEFOQuery.Quantity_Base;
                PendingLotQtyBase := ToteMath.GetLotQtyAlreadyInWorksheet(WhseWkshTemplateName, WhseWkshName, ReceiveLocation, BinContent."Item No.", FEFOQuery.Lot_No_);
                LotAvailQtyBase -= PendingLotQtyBase;

                if LotAvailQtyBase >= QtyPerTote then begin
                    TotesAvail := Round(LotAvailQtyBase / QtyPerTote, 1, '>');
                    if TotesAvail > TotesNeeded then
                        TotesToMove := TotesNeeded
                    else
                        TotesToMove := TotesAvail;

                    if TotesToMove > 0 then begin
                        MoveQtyBase := TotesToMove * QtyPerTote;
                        PlacedBase := PlaceAcrossDestBins(
                            BinCapacities, MoveQtyBase, BinContent,
                            FEFOQuery.Lot_No_, FEFOQuery.Expiration_Date,
                            FEFOQuery.Unit_of_Measure_Code, FEFOQuery.Qty_per_Unit_of_Measure,
                            ToZoneCode, FEFOQuery.Bin_Code,
                            FEFOQuery.Manufacturer_Code, FEFOQuery.Package_No_);

                        // Convert placed base qty back to whole totes for the counter.
                        TotesPlaced := Round(PlacedBase / QtyPerTote, 1, '<');
                        TotesNeeded -= TotesPlaced;
                        if PlacedBase = 0 then
                            break; // destination zone is full
                    end;
                end;
            end;
        end;
        FEFOQuery.Close();
    end;

    /// <summary>
    /// Computes remaining capacity (base qty) for every destination bin in the zone
    /// holding the item. Capacity = Max.Qty. − current avail − in-flight Place activity
    /// − pending worksheet lines, all targeting that specific bin.
    /// </summary>
    local procedure BuildDestBinCapacities(ItemNo: Code[20]; ToZoneCode: Code[10]; var BinCapacities: Dictionary of [Code[20], Decimal])
    var
        BinContent: Record "Bin Content";
        WhseActLine: Record "Warehouse Activity Line";
        WhseWkshLine: Record "Whse. Worksheet Line";
        MaxQtyBase: Decimal;
        Capacity: Decimal;
    begin
        Clear(BinCapacities);
        BinContent.SetRange("Location Code", ReceiveLocation);
        BinContent.SetRange("Zone Code", ToZoneCode);
        BinContent.SetRange("Item No.", ItemNo);
        if BinContent.FindSet() then
            repeat
                MaxQtyBase := BinContent."Max. Qty." * BinContent."Qty. per Unit of Measure";
                if MaxQtyBase > 0 then begin
                    WhseActLine.Reset();
                    WhseActLine.SetRange("Activity Type", WhseActLine."Activity Type"::Movement);
                    WhseActLine.SetRange("Action Type", WhseActLine."Action Type"::Place);
                    WhseActLine.SetRange("Location Code", ReceiveLocation);
                    WhseActLine.SetRange("Zone Code", ToZoneCode);
                    WhseActLine.SetRange("Bin Code", BinContent."Bin Code");
                    WhseActLine.SetRange("Item No.", ItemNo);
                    WhseActLine.CalcSums("Qty. Outstanding (Base)");

                    WhseWkshLine.Reset();
                    WhseWkshLine.SetRange("Worksheet Template Name", WhseWkshTemplateName);
                    WhseWkshLine.SetRange(Name, WhseWkshName);
                    WhseWkshLine.SetRange("Location Code", ReceiveLocation);
                    WhseWkshLine.SetRange("From Zone Code", HighBayZone);
                    WhseWkshLine.SetRange("To Zone Code", ToZoneCode);
                    WhseWkshLine.SetRange("To Bin Code", BinContent."Bin Code");
                    WhseWkshLine.SetRange("Item No.", ItemNo);
                    WhseWkshLine.CalcSums("Qty. (Base)");

                    Capacity := MaxQtyBase
                              - BinContent.CalcQtyAvailToTake(0)
                              - WhseActLine."Qty. Outstanding (Base)"
                              - WhseWkshLine."Qty. (Base)";
                    if Capacity > 0 then
                        BinCapacities.Add(BinContent."Bin Code", Capacity);
                end;
            until BinContent.Next() = 0;
    end;

    /// <summary>
    /// Distributes a quantity across destination bins, oldest map order first, capped
    /// per bin by remaining capacity. Inserts one worksheet line per bin that receives
    /// stock; decrements the capacity map in place. Returns total base qty actually placed.
    /// </summary>
    local procedure PlaceAcrossDestBins(var BinCapacities: Dictionary of [Code[20], Decimal]; QtyToPlaceBase: Decimal; var BinContent: Record "Bin Content"; LotNo: Code[50]; ExpirationDate: Date; UoMCode: Code[10]; QtyPerUoM: Decimal; ToZoneCode: Code[10]; FromBinCode: Code[20]; ManufacturerCode: Code[10]; PackageNo: Code[50]): Decimal
    var
        BinCodes: List of [Code[20]];
        BinCode: Code[20];
        Cap: Decimal;
        Portion: Decimal;
        Placed: Decimal;
    begin
        BinCodes := BinCapacities.Keys();
        foreach BinCode in BinCodes do begin
            if QtyToPlaceBase <= 0 then
                break;
            Cap := BinCapacities.Get(BinCode);
            if Cap <= 0 then
                continue;
            if Cap >= QtyToPlaceBase then
                Portion := QtyToPlaceBase
            else
                Portion := Cap;

            InsertMovementWkshLine(
                BinContent, LotNo, ExpirationDate, UoMCode, QtyPerUoM,
                Portion, ToZoneCode, BinCode, FromBinCode, ManufacturerCode, PackageNo);

            BinCapacities.Set(BinCode, Cap - Portion);
            QtyToPlaceBase -= Portion;
            Placed += Portion;
        end;
        exit(Placed);
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
