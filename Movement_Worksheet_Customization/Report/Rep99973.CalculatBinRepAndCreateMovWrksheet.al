// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Warehouse.Structure;

using Microsoft.Inventory.Location;
using Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Worksheet;
using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Tracking;

report 99973 "Calculate Bin Rep And Movement"
{
    Caption = 'Calculate Movement Replenishment';
    ProcessingOnly = true;

    dataset
    {
        dataitem("Bin Content"; "Bin Content")
        {
            DataItemTableView = sorting("Location Code", "Item No.", "Warehouse Class Code", Fixed, "Bin Ranking") order(descending) where(Fixed = filter(true), "Min. Qty." = filter(> 0));
            RequestFilterFields = "Item No.", "Bin Code";

            trigger OnAfterGetRecord()
            begin
                ProcessPickBulkBinContent("Bin Content");
            end;

            trigger OnPostDataItem()
            begin
                if LinesInserted = 0 then
                    if not HideDialog then
                        Message(NothingToReplenishMsg);
            end;

            trigger OnPreDataItem()
            begin
                InitializeLocations();

                if PickBulkLocation = '' then
                    Error(PickBulkLocNotSetErr);
                if BulkLocation = '' then
                    Error(BulkLocNotSetErr);
                if BulkDecantZone = '' then
                    Error(BulkDecantZoneNotFoundErr);
                if HighBayZone = '' then
                    Error(HighBayZoneNotFoundErr);
                if PickBulkZone = '' then
                    Error(PickBulkZoneNotFoundErr);
                if BulkDecantBin = '' then
                    Error(BulkDecantBinNotFoundErr);
                if GenDecantZone = '' then
                    Error(GenDecantZoneNotFoundErr);
                if GenDecantBin = '' then
                    Error(GenDecantBinNotFoundErr);
                if HighBayBin = '' then
                    Error(HighBayBinNotFoundErr);

                WhseWorksheetName.Get(WhseWkshTemplateName, WhseWkshName, BulkLocation);

                SetRange("Location Code", PickBulkLocation);
                SetRange("Zone Code", PickBulkZone);

                SetNextLineNo();
                LinesInserted := 0;
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(WorksheetTemplateName; WhseWkshTemplateName)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Worksheet Template Name';
                        TableRelation = "Whse. Worksheet Template";
                        ToolTip = 'Specifies the name of the worksheet template that applies to the movement lines.';

                        trigger OnValidate()
                        begin
                            if WhseWkshTemplateName = '' then
                                WhseWkshName := '';
                        end;
                    }
                    field(WorksheetName; WhseWkshName)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Worksheet Name';
                        ToolTip = 'Specifies the name of the worksheet the movement lines will belong to.';

                        trigger OnLookup(var Text: Text): Boolean
                        begin
                            InitializeLocations();
                            WhseWorksheetName.SetRange("Worksheet Template Name", WhseWkshTemplateName);
                            WhseWorksheetName.SetRange("Location Code", BulkLocation);
                            if PAGE.RunModal(0, WhseWorksheetName) = ACTION::LookupOK then
                                WhseWkshName := WhseWorksheetName.Name;
                        end;

                        trigger OnValidate()
                        begin
                            InitializeLocations();
                            WhseWorksheetName.Get(WhseWkshTemplateName, WhseWkshName, BulkLocation);
                        end;
                    }
                    field(LocCode; LocationCode)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Location Code';
                        TableRelation = Location;
                        ToolTip = 'Specifies the PICK BULK location whose fixed bins are checked for stock below Min. Qty.';
                    }
                    field(DoNotFillQtytoHandle; DoNotFillQtytoHandle)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Do Not Fill Qty. to Handle';
                        ToolTip = 'Specifies that the Quantity to Handle field on each worksheet line must be filled manually.';
                    }
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }

    var
        WhseWorksheetName: Record "Whse. Worksheet Name";
        G_Events: Codeunit Events;
        //G_SingleInstanceCU: Codeunit SingleInstanceCU;
        NothingToReplenishMsg: Label 'There is nothing to replenish.';
        PickBulkLocNotSetErr: Label 'The PICK BULK Location is not set. Configure it in Warehouse Setup (MAIN Warehouse) or enter it on the request page.';
        BulkLocNotSetErr: Label 'The BULK Location is not set. Configure the RECEIVE Warehouse in Warehouse Setup.';
        BulkDecantZoneNotFoundErr: Label 'No zone with the Bulk flag was found in the BULK Location.';
        HighBayZoneNotFoundErr: Label 'No zone with the High Bay flag was found in the BULK Location.';
        PickBulkZoneNotFoundErr: Label 'No zone with the Bulk flag was found in the PICK BULK Location.';
        BulkDecantBinNotFoundErr: Label 'No bin was found in the BULK DECANT zone of the BULK Location.';
        HighBayBinNotFoundErr: Label 'No bin was found in the HIGHBAY zone of the BULK Location.';
        GenDecantZoneNotFoundErr: Label 'No zone with the General Decant flag was found in the BULK Location.';
        GenDecantBinNotFoundErr: Label 'No bin was found in the GEN DECANT zone of the BULK Location.';

    protected var
        WhseWkshTemplateName: Code[10];
        WhseWkshName: Code[10];
        DoNotFillQtytoHandle: Boolean;
        HideDialog: Boolean;
        LocationCode: Code[10];
        AllowBreakbulk: Boolean;
        BulkLocation: Code[10];
        PickBulkLocation: Code[10];
        BulkDecantZone: Code[10];
        BulkDecantBin: Code[20];
        GenDecantZone: Code[10];
        GenDecantBin: Code[20];
        HighBayZone: Code[10];
        HighBayBin: Code[20];
        PickBulkZone: Code[10];
        NextLineNo: Integer;
        LinesInserted: Integer;

    procedure InitializeRequest(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10]; AllowBreakbulk2: Boolean; HideDialog2: Boolean; DoNotFillQtytoHandle2: Boolean)
    begin
        WhseWkshTemplateName := WhseWkshTemplateName2;
        WhseWkshName := WhseWkshName2;
        LocationCode := LocationCode2;
        AllowBreakbulk := AllowBreakbulk2;
        HideDialog := HideDialog2;
        DoNotFillQtytoHandle := DoNotFillQtytoHandle2;
    end;

    local procedure InitializeLocations()
    var
        L_Bin: Record Bin;
    begin
        // PICK BULK location from request page or setup
        PickBulkLocation := LocationCode;
        if PickBulkLocation = '' then
            PickBulkLocation := G_Events.GetMainWarehouse();

        // BULK location from setup
        BulkLocation := G_Events.GetReceiveWarehouse();

        // Zone codes from boolean flags on Zone table
        BulkDecantZone := G_Events.GetPickBulkZone(BulkLocation);
        GenDecantZone := G_Events.GetGenDecantZone(BulkLocation);
        HighBayZone := G_Events.GetPickHighBayZone(BulkLocation);
        PickBulkZone := G_Events.GetPickBulkZone(PickBulkLocation);

        // Get first bin in each zone
        Clear(BulkDecantBin);
        Clear(GenDecantBin);
        Clear(HighBayBin);

        L_Bin.Reset();
        L_Bin.SetRange("Location Code", BulkLocation);
        L_Bin.SetRange("Zone Code", BulkDecantZone);
        if L_Bin.FindFirst() then
            BulkDecantBin := L_Bin.Code;

        L_Bin.Reset();
        L_Bin.SetRange("Location Code", BulkLocation);
        L_Bin.SetRange("Zone Code", GenDecantZone);
        if L_Bin.FindFirst() then
            GenDecantBin := L_Bin.Code;

        L_Bin.Reset();
        L_Bin.SetRange("Location Code", BulkLocation);
        L_Bin.SetRange("Zone Code", HighBayZone);
        if L_Bin.FindFirst() then
            HighBayBin := L_Bin.Code;
    end;

    local procedure SetNextLineNo()
    var
        L_WhseWkshLine: Record "Whse. Worksheet Line";
    begin
        L_WhseWkshLine.SetRange("Worksheet Template Name", WhseWkshTemplateName);
        L_WhseWkshLine.SetRange(Name, WhseWkshName);
        L_WhseWkshLine.SetRange("Location Code", BulkLocation);
        if L_WhseWkshLine.FindLast() then
            NextLineNo := L_WhseWkshLine."Line No." + 10000
        else
            NextLineNo := 10000;
    end;

    local procedure ProcessPickBulkBinContent(var P_BinContent: Record "Bin Content")
    var
        L_FEFOQuery: Query "FEFO Whse Entry HIGHBAY";
        L_Item: Record Item;
        L_CurrentAvail: Decimal;
        L_NeedQty: Decimal;
        L_AvailQty: Decimal;
        L_PendingQty: Decimal;
        L_MoveQty: Decimal;
        L_ToZoneCode: Code[10];
        L_ToBinCode: Code[20];
    begin
        // Check if stock is below Min. Qty.
        L_CurrentAvail := P_BinContent.CalcQtyAvailToTake(0);
        if L_CurrentAvail >= P_BinContent."Min. Qty." then
            exit;

        // Determine destination based on Item.BULK flag
        L_Item.SetLoadFields(BULK);
        if not L_Item.Get(P_BinContent."Item No.") then
            exit;

        if L_Item.BULK then begin
            L_ToZoneCode := BulkDecantZone;
            L_ToBinCode := BulkDecantBin;
        end else begin
            L_ToZoneCode := GenDecantZone;
            L_ToBinCode := GenDecantBin;
        end;

        // Qty needed to bring PICK BULK up to Max. Qty.
        L_NeedQty := P_BinContent."Max. Qty." - L_CurrentAvail;
        if L_NeedQty <= 0 then
            exit;

        // Deduct stock already available in the destination bin (BULK DECANT or GEN DECANT)
        L_NeedQty -= GetDestinationBinAvailQty(P_BinContent."Item No.", L_ToZoneCode, L_ToBinCode);
        if L_NeedQty <= 0 then
            exit;

        // Deduct what is already pending in the worksheet for this item
        L_NeedQty -= GetQtyAlreadyInWorksheet(P_BinContent."Item No.", L_ToZoneCode, L_ToBinCode);
        if L_NeedQty <= 0 then
            exit;

        // FEFO: iterate HIGHBAY warehouse entries by earliest expiration date first
        L_FEFOQuery.SetFilter(L_FEFOQuery.Location_Code, '%1', BulkLocation);
        L_FEFOQuery.SetFilter(L_FEFOQuery.Zone_Code, '%1', HighBayZone);
        L_FEFOQuery.SetFilter(L_FEFOQuery.Bin_Code, '%1', HighBayBin);
        L_FEFOQuery.SetFilter(L_FEFOQuery.Item_No_, '%1', P_BinContent."Item No.");
        L_FEFOQuery.SetFilter(L_FEFOQuery.Quantity, '>%1', 0);
        L_FEFOQuery.Open();
        while L_FEFOQuery.Read() and (L_NeedQty > 0) do begin
            L_AvailQty := L_FEFOQuery.Quantity;

            // Deduct qty already in worksheet for this specific lot
            L_PendingQty := GetLotQtyAlreadyInWorksheet(
                P_BinContent."Item No.", L_FEFOQuery.Lot_No_);
            L_AvailQty -= L_PendingQty;

            if L_AvailQty > 0 then begin
                if L_AvailQty >= L_NeedQty then
                    L_MoveQty := L_NeedQty
                else
                    L_MoveQty := L_AvailQty;

                InsertMovementWkshLine(
                    P_BinContent,
                    L_FEFOQuery.Lot_No_,
                    L_FEFOQuery.Expiration_Date,
                    L_FEFOQuery.Unit_of_Measure_Code,
                    L_MoveQty,
                    L_ToZoneCode,
                    L_ToBinCode);

                L_NeedQty -= L_MoveQty;
            end;
        end;
        L_FEFOQuery.Close();
    end;

    local procedure GetDestinationBinAvailQty(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]; P_ToBinCode: Code[20]): Decimal
    var
        L_DestBinContent: Record "Bin Content";
        L_TotalAvail: Decimal;
    begin
        L_DestBinContent.SetRange("Location Code", BulkLocation);
        L_DestBinContent.SetRange("Zone Code", P_ToZoneCode);
        L_DestBinContent.SetRange("Bin Code", P_ToBinCode);
        L_DestBinContent.SetRange("Item No.", P_ItemNo);
        if L_DestBinContent.FindSet() then
            repeat
                L_TotalAvail += L_DestBinContent.CalcQtyAvailToTake(0);
            until L_DestBinContent.Next() = 0;
        exit(L_TotalAvail);
    end;

    local procedure GetQtyAlreadyInWorksheet(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]; P_ToBinCode: Code[20]): Decimal
    var
        L_WhseWkshLine: Record "Whse. Worksheet Line";
    begin
        L_WhseWkshLine.SetRange("Worksheet Template Name", WhseWkshTemplateName);
        L_WhseWkshLine.SetRange(Name, WhseWkshName);
        L_WhseWkshLine.SetRange("Location Code", BulkLocation);
        L_WhseWkshLine.SetRange("From Zone Code", HighBayZone);
        L_WhseWkshLine.SetRange("From Bin Code", HighBayBin);
        L_WhseWkshLine.SetRange("To Zone Code", P_ToZoneCode);
        L_WhseWkshLine.SetRange("To Bin Code", P_ToBinCode);
        L_WhseWkshLine.SetRange("Item No.", P_ItemNo);
        L_WhseWkshLine.CalcSums(Quantity);
        exit(L_WhseWkshLine.Quantity);
    end;

    local procedure GetLotQtyAlreadyInWorksheet(P_ItemNo: Code[20]; P_LotNo: Code[50]): Decimal
    var
        L_WhseItemTrackingLine: Record "Whse. Item Tracking Line";
    begin
        L_WhseItemTrackingLine.SetRange("Source Type", DATABASE::"Whse. Worksheet Line");
        L_WhseItemTrackingLine.SetRange("Source ID", WhseWkshName);
        L_WhseItemTrackingLine.SetRange("Source Batch Name", WhseWkshTemplateName);
        L_WhseItemTrackingLine.SetRange("Location Code", BulkLocation);
        L_WhseItemTrackingLine.SetRange("Item No.", P_ItemNo);
        L_WhseItemTrackingLine.SetRange("Lot No.", P_LotNo);
        L_WhseItemTrackingLine.CalcSums("Quantity (Base)");
        exit(L_WhseItemTrackingLine."Quantity (Base)");
    end;

    local procedure InsertMovementWkshLine(var P_BinContent: Record "Bin Content"; P_LotNo: Code[50]; P_ExpirationDate: Date; P_UoMCode: Code[10]; P_MoveQty: Decimal; P_ToZoneCode: Code[10]; P_ToBinCode: Code[20])
    var
        L_WhseWkshLine: Record "Whse. Worksheet Line";
        L_Item: Record Item;
    begin
        L_WhseWkshLine.Init();
        L_WhseWkshLine."Worksheet Template Name" := WhseWkshTemplateName;
        L_WhseWkshLine.Name := WhseWkshName;
        L_WhseWkshLine."Location Code" := BulkLocation;
        L_WhseWkshLine."Line No." := NextLineNo;

        L_WhseWkshLine.Validate("Item No.", P_BinContent."Item No.");

        L_WhseWkshLine."Unit of Measure Code" := P_UoMCode;
        L_WhseWkshLine."Qty. per Unit of Measure" := P_BinContent."Qty. per Unit of Measure";

        L_WhseWkshLine."From Zone Code" := HighBayZone;
        L_WhseWkshLine."From Bin Code" := HighBayBin;
        L_WhseWkshLine."To Zone Code" := P_ToZoneCode;
        L_WhseWkshLine."To Bin Code" := P_ToBinCode;

        L_WhseWkshLine.Validate(Quantity, P_MoveQty);
        if not DoNotFillQtytoHandle then
            L_WhseWkshLine.Validate("Qty. to Handle", P_MoveQty);

        if L_Item.Get(P_BinContent."Item No.") then
            L_WhseWkshLine.Description := L_Item.Description;

        L_WhseWkshLine.Insert(true);

        // Create Whse. Item Tracking Line for the lot
        InsertWhseItemTrackingLine(L_WhseWkshLine, P_LotNo, P_ExpirationDate, P_MoveQty);

        NextLineNo += 10000;
        LinesInserted += 1;
    end;

    local procedure InsertWhseItemTrackingLine(var P_WhseWkshLine: Record "Whse. Worksheet Line"; P_LotNo: Code[50]; P_ExpirationDate: Date; P_Qty: Decimal)
    var
        L_WhseItemTrackingLine: Record "Whse. Item Tracking Line";
        L_NextEntryNo: Integer;
    begin
        if P_LotNo = '' then
            exit;

        L_WhseItemTrackingLine.Reset();
        if L_WhseItemTrackingLine.FindLast() then
            L_NextEntryNo := L_WhseItemTrackingLine."Entry No." + 1
        else
            L_NextEntryNo := 1;

        L_WhseItemTrackingLine.Init();
        L_WhseItemTrackingLine."Entry No." := L_NextEntryNo;
        L_WhseItemTrackingLine."Source Type" := DATABASE::"Whse. Worksheet Line";
        L_WhseItemTrackingLine."Source Subtype" := 0;
        L_WhseItemTrackingLine."Source ID" := P_WhseWkshLine.Name;
        L_WhseItemTrackingLine."Source Batch Name" := P_WhseWkshLine."Worksheet Template Name";
        L_WhseItemTrackingLine."Source Prod. Order Line" := 0;
        L_WhseItemTrackingLine."Source Ref. No." := P_WhseWkshLine."Line No.";

        L_WhseItemTrackingLine."Item No." := P_WhseWkshLine."Item No.";
        L_WhseItemTrackingLine."Variant Code" := P_WhseWkshLine."Variant Code";
        L_WhseItemTrackingLine."Location Code" := P_WhseWkshLine."Location Code";

        L_WhseItemTrackingLine."Lot No." := P_LotNo;
        L_WhseItemTrackingLine."Expiration Date" := P_ExpirationDate;

        L_WhseItemTrackingLine."Quantity (Base)" := P_Qty * P_WhseWkshLine."Qty. per Unit of Measure";
        L_WhseItemTrackingLine."Qty. to Handle (Base)" := P_Qty * P_WhseWkshLine."Qty. per Unit of Measure";
        L_WhseItemTrackingLine."Qty. per Unit of Measure" := P_WhseWkshLine."Qty. per Unit of Measure";

        L_WhseItemTrackingLine.Insert(true);
    end;

    // trigger OnPreReport()
    // begin
    //     G_SingleInstanceCU.ExecutedFromCustomMovementWorksheet(true);
    // end;

    // trigger OnPostReport()
    // begin
    //     G_SingleInstanceCU.ExecutedFromCustomMovementWorksheet(false);
    // end;
}
