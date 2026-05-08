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
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Activity;

report 99973 "Calculate Bin Rep And Movement"
{
    Caption = 'Calculate Movement Replenishment';
    ProcessingOnly = true;

    dataset
    {
        dataitem("Bin Content"; "Bin Content")
        {
            DataItemTableView = sorting("Location Code", "Item No.", "Warehouse Class Code", Fixed, "Bin Ranking") order(descending) where("Min. Qty." = filter(> 0));
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

                WhseWorksheetName.Get(WhseWkshTemplateName, WhseWkshName, ReceiveLocation);

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
                        Visible = false;

                        trigger OnLookup(var Text: Text): Boolean
                        begin
                            InitializeLocations();
                            WhseWorksheetName.SetRange("Worksheet Template Name", WhseWkshTemplateName);
                            WhseWorksheetName.SetRange("Location Code", ReceiveLocation);
                            if PAGE.RunModal(0, WhseWorksheetName) = ACTION::LookupOK then
                                WhseWkshName := WhseWorksheetName.Name;
                        end;

                        trigger OnValidate()
                        begin
                            InitializeLocations();
                            WhseWorksheetName.Get(WhseWkshTemplateName, WhseWkshName, ReceiveLocation);
                        end;
                    }
                    field(LocCode; LocationCode)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Location Code';
                        TableRelation = Location;
                        ToolTip = 'Specifies the PICK BULK location whose fixed bins are checked for stock below Min. Qty.';
                        Visible = false;
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
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        NothingToReplenishMsg: Label 'There is nothing to replenish.';
        PickBulkLocNotSetErr: Label 'The PICK BULK Location is not set. Configure it in Warehouse Setup (MAIN Warehouse) or enter it on the request page.';
        ReceiveLocNotSetErr: Label 'The BULK Location is not set. Configure the RECEIVE Warehouse in Warehouse Setup.';
        BulkDecantZoneNotFoundErr: Label 'No zone with the Bulk flag was found in the BULK Location.';
        HighBayZoneNotFoundErr: Label 'No zone with the High Bay flag was found in the BULK Location.';
        PickBulkZoneNotFoundErr: Label 'No zone with the Bulk flag was found in the PICK BULK Location.';
        GenDecantZoneNotFoundErr: Label 'No zone with the General Decant flag was found in the BULK Location.';

    protected var
        WhseWkshTemplateName: Code[10];
        WhseWkshName: Code[10];
        DoNotFillQtytoHandle: Boolean;
        HideDialog: Boolean;
        LocationCode: Code[10];
        AllowBreakbulk: Boolean;
        ReceiveLocation: Code[10];
        PickBulkLocation: Code[10];
        BulkDecantZone: Code[10];
        GenDecantZone: Code[10];
        HighBayZone: Code[10];
        PickBulkZone: Code[10];
        MAInGENDCNTZONE: Code[10];
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
    begin
        // PICK BULK location from request page or setup
        PickBulkLocation := LocationCode;
        if PickBulkLocation = '' then
            PickBulkLocation := G_KamWhseSetupLookup.GetMainLocation();

        // BULK location from setup
        ReceiveLocation := G_KamWhseSetupLookup.GetReceiveLocation();

        // Zone codes from boolean flags on Zone table
        BulkDecantZone := G_KamWhseSetupLookup.GetBulkZone(ReceiveLocation);
        GenDecantZone := G_KamWhseSetupLookup.GetDecantZone(ReceiveLocation);
        HighBayZone := G_KamWhseSetupLookup.GetHighBayZone(ReceiveLocation);
        PickBulkZone := G_KamWhseSetupLookup.GetBulkZone(PickBulkLocation);
    end;

    local procedure GetBinFromBinContent(P_ItemNo: Code[20]; P_LocationCode: Code[10]; P_ZoneCode: Code[10]): Code[20]
    var
        L_BinContent: Record "Bin Content";
    begin
        L_BinContent.SetRange("Location Code", P_LocationCode);
        L_BinContent.SetRange("Zone Code", P_ZoneCode);
        L_BinContent.SetRange("Item No.", P_ItemNo);
        if L_BinContent.FindFirst() then
            exit(L_BinContent."Bin Code");
        exit('');
    end;

    local procedure SetNextLineNo()
    var
        L_WhseWkshLine: Record "Whse. Worksheet Line";
    begin
        L_WhseWkshLine.SetRange("Worksheet Template Name", WhseWkshTemplateName);
        L_WhseWkshLine.SetRange(Name, WhseWkshName);
        L_WhseWkshLine.SetRange("Location Code", ReceiveLocation);
        if L_WhseWkshLine.FindLast() then
            NextLineNo := L_WhseWkshLine."Line No." + 10000
        else
            NextLineNo := 10000;
    end;

    local procedure ProcessPickBulkBinContent(var P_BinContent: Record "Bin Content")
    var
        L_Item: Record Item;
        L_ToZoneCode: Code[10];
        L_ToBinCode: Code[20];
    begin
        // Only process PICK BULK fixed bins
        if P_BinContent."Location Code" <> PickBulkLocation then
            exit;


        L_Item.SetLoadFields("Routing Type");
        if not L_Item.Get(P_BinContent."Item No.") then
            exit;

        // Routing Type drives destination zone in BULK Location.
        // BULK -> BULK DECANT; Flowrack and Static -> GEN DECANT (both pulled from HIGHBAY).
        case L_Item."Routing Type" of
            L_Item."Routing Type"::BULK:
                begin
                    if P_BinContent."Zone Code" <> PickBulkZone then
                        exit;
                    L_ToZoneCode := BulkDecantZone;
                end;
            L_Item."Routing Type"::Flowrack,
            L_Item."Routing Type"::"Static":
                begin
                    MAInGENDCNTZONE := G_KamWhseSetupLookup.GetDecantZonefromBinContent(PickBulkLocation, "Bin Content"."Item No.");
                    if P_BinContent."Zone Code" <> MAInGENDCNTZONE then
                        exit;
                    L_ToZoneCode := GenDecantZone;
                end;
            else
                exit;
        end;

        L_ToBinCode := GetBinFromBinContent(P_BinContent."Item No.", ReceiveLocation, L_ToZoneCode);
        if L_ToBinCode = '' then
            exit;

        case L_Item."Routing Type" of
            L_Item."Routing Type"::BULK,
            L_Item."Routing Type"::"Static":
                // Qty-based, Max. Qty. of the iterated bin (PICK BULK for BULK; GEN DECANT for Static).
                ProcessBulkItem(P_BinContent, L_ToZoneCode, L_ToBinCode);
            L_Item."Routing Type"::Flowrack:
                // Tote-based, Number of Totes in a Bin.
                ProcessNonBulkItem(P_BinContent, L_ToZoneCode, L_ToBinCode);
        end;
    end;

    local procedure ProcessBulkItem(var P_BinContent: Record "Bin Content"; P_ToZoneCode: Code[10]; P_ToBinCode: Code[20])
    var
        L_FEFOQuery: Query "FEFO Whse Entry HIGHBAY";
        L_PickBulkAvailBase: Decimal;
        L_MinQtyBase: Decimal;
        L_MaxQtyBase: Decimal;
        L_NeedQtyBase: Decimal;
        L_LotAvailBase: Decimal;
        L_PendingLotBase: Decimal;
        L_MoveQtyBase: Decimal;
    begin
        // Trigger: PICK BULK (MAIN WH) available qty < PICK BULK Min. Qty.
        L_PickBulkAvailBase := P_BinContent.CalcQtyAvailToTake(0);
        L_MinQtyBase := P_BinContent."Min. Qty." * P_BinContent."Qty. per Unit of Measure";
        if L_PickBulkAvailBase >= L_MinQtyBase then
            exit;

        // Size: bring BULK destination up to Max. Qty. of the PICK BULK bin.
        L_MaxQtyBase := P_BinContent."Max. Qty." * P_BinContent."Qty. per Unit of Measure";
        if L_MaxQtyBase <= 0 then
            exit;

        L_NeedQtyBase :=
            L_MaxQtyBase
            - L_PickBulkAvailBase
            - GetDestinationZoneAvailQty(P_BinContent."Item No.", P_ToZoneCode)
            - GetActivityQtyToDestination(P_BinContent."Item No.", P_ToZoneCode)
            - GetQtyAlreadyInWorksheet(P_BinContent."Item No.", P_ToZoneCode);
        if L_NeedQtyBase <= 0 then
            exit;

        // FEFO from HIGHBAY, partial-lot allowed.
        L_FEFOQuery.SetFilter(L_FEFOQuery.Location_Code, '%1', ReceiveLocation);
        L_FEFOQuery.SetFilter(L_FEFOQuery.Zone_Code, '%1', HighBayZone);
        L_FEFOQuery.SetFilter(L_FEFOQuery.Item_No_, '%1', P_BinContent."Item No.");
        L_FEFOQuery.SetFilter(L_FEFOQuery.Quantity_Base, '>%1', 0);
        L_FEFOQuery.Open();
        while L_FEFOQuery.Read() and (L_NeedQtyBase > 0) do begin
            L_LotAvailBase := L_FEFOQuery.Quantity_Base;
            L_PendingLotBase := GetLotQtyAlreadyInWorksheet(P_BinContent."Item No.", L_FEFOQuery.Lot_No_);
            L_LotAvailBase -= L_PendingLotBase;

            if L_LotAvailBase > 0 then begin
                if L_LotAvailBase >= L_NeedQtyBase then
                    L_MoveQtyBase := L_NeedQtyBase
                else
                    L_MoveQtyBase := L_LotAvailBase;

                InsertMovementWkshLine(
                    P_BinContent,
                    L_FEFOQuery.Lot_No_,
                    L_FEFOQuery.Expiration_Date,
                    L_FEFOQuery.Unit_of_Measure_Code,
                    L_FEFOQuery.Qty_per_Unit_of_Measure,
                    L_MoveQtyBase,
                    P_ToZoneCode,
                    P_ToBinCode,
                    L_FEFOQuery.Bin_Code, L_FEFOQuery.Manufacturer_Code, L_FEFOQuery.Package_No_);

                L_NeedQtyBase -= L_MoveQtyBase;
            end;
        end;
        L_FEFOQuery.Close();
    end;

    local procedure ProcessNonBulkItem(var P_BinContent: Record "Bin Content"; P_ToZoneCode: Code[10]; P_ToBinCode: Code[20])
    var
        L_FEFOQuery: Query "FEFO Whse Entry HIGHBAY";
        L_PickBulkAvailBase: Decimal;
        L_MinQtyBase: Decimal;
        L_QtyPerTote: Decimal;
        L_LotAvailQtyBase: Decimal;
        L_PendingLotQtyBase: Decimal;
        L_MoveQtyBase: Decimal;
        L_TargetTotes: Integer;
        L_PickBulkTotes: Integer;
        L_DestTotes: Integer;
        L_ActivityTotes: Integer;
        L_PendingTotes: Integer;
        L_TotesNeeded: Integer;
        L_TotesAvail: Integer;
        L_TotesToMove: Integer;
    begin
        // Trigger: PICK BULK bin available qty < PICK BULK Min. Qty.
        L_PickBulkAvailBase := P_BinContent.CalcQtyAvailToTake(0);
        L_MinQtyBase := P_BinContent."Min. Qty." * P_BinContent."Qty. per Unit of Measure";
        if L_PickBulkAvailBase >= L_MinQtyBase then
            exit;

        // Tote-based sizing counted inside PICK BULK (mixed manufacturers, whole totes only).
        L_TargetTotes := P_BinContent."Number of Totes in a Bin";
        if L_TargetTotes <= 0 then
            exit;

        L_PickBulkTotes := GetPickBulkTotes(P_BinContent);
        L_DestTotes := GetDestinationTotes(P_BinContent."Item No.", P_ToZoneCode);
        L_ActivityTotes := GetActivityTotesToDestination(P_BinContent."Item No.", P_ToZoneCode);
        L_PendingTotes := GetPendingTotesInWorksheet(P_BinContent."Item No.", P_ToZoneCode);
        L_TotesNeeded := L_TargetTotes - L_PickBulkTotes - L_DestTotes - L_ActivityTotes - L_PendingTotes;
        if L_TotesNeeded <= 0 then
            exit;

        // FEFO from HIGHBAY — whole totes only, per manufacturer's Qty per Tote.
        L_FEFOQuery.SetFilter(L_FEFOQuery.Location_Code, '%1', ReceiveLocation);
        L_FEFOQuery.SetFilter(L_FEFOQuery.Zone_Code, '%1', HighBayZone);
        L_FEFOQuery.SetFilter(L_FEFOQuery.Item_No_, '%1', P_BinContent."Item No.");
        L_FEFOQuery.SetFilter(L_FEFOQuery.Quantity_Base, '>%1', 0);
        L_FEFOQuery.Open();
        while L_FEFOQuery.Read() and (L_TotesNeeded > 0) do begin
            L_QtyPerTote := GetQtyPerTote(P_BinContent."Item No.", L_FEFOQuery.Manufacturer_Code);
            if L_QtyPerTote > 0 then begin
                L_LotAvailQtyBase := L_FEFOQuery.Quantity_Base;
                L_PendingLotQtyBase := GetLotQtyAlreadyInWorksheet(P_BinContent."Item No.", L_FEFOQuery.Lot_No_);
                L_LotAvailQtyBase -= L_PendingLotQtyBase;

                if L_LotAvailQtyBase >= L_QtyPerTote then begin
                    L_TotesAvail := Round(L_LotAvailQtyBase / L_QtyPerTote, 1, '>');
                    if L_TotesAvail > L_TotesNeeded then
                        L_TotesToMove := L_TotesNeeded
                    else
                        L_TotesToMove := L_TotesAvail;

                    if L_TotesToMove > 0 then begin
                        L_MoveQtyBase := L_TotesToMove * L_QtyPerTote;
                        InsertMovementWkshLine(
                            P_BinContent,
                            L_FEFOQuery.Lot_No_,
                            L_FEFOQuery.Expiration_Date,
                            L_FEFOQuery.Unit_of_Measure_Code,
                            L_FEFOQuery.Qty_per_Unit_of_Measure,
                            L_MoveQtyBase,
                            P_ToZoneCode,
                            P_ToBinCode,
                            L_FEFOQuery.Bin_Code, L_FEFOQuery.Manufacturer_Code, L_FEFOQuery.Package_No_);

                        L_TotesNeeded -= L_TotesToMove;
                    end;
                end;
            end;
        end;
        L_FEFOQuery.Close();
    end;

    local procedure GetQtyAlreadyInWorksheet(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]): Decimal
    var
        L_WhseWkshLine: Record "Whse. Worksheet Line";
    begin
        L_WhseWkshLine.SetRange("Worksheet Template Name", WhseWkshTemplateName);
        L_WhseWkshLine.SetRange(Name, WhseWkshName);
        L_WhseWkshLine.SetRange("Location Code", ReceiveLocation);
        L_WhseWkshLine.SetRange("From Zone Code", HighBayZone);
        L_WhseWkshLine.SetRange("To Zone Code", P_ToZoneCode);
        L_WhseWkshLine.SetRange("Item No.", P_ItemNo);
        L_WhseWkshLine.CalcSums("Qty. (Base)");
        exit(L_WhseWkshLine."Qty. (Base)");
    end;

    local procedure GetDestinationZoneAvailQty(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]): Decimal
    var
        L_DestBinContent: Record "Bin Content";
        L_TotalAvail: Decimal;
    begin
        L_DestBinContent.SetRange("Location Code", ReceiveLocation);
        L_DestBinContent.SetRange("Zone Code", P_ToZoneCode);
        L_DestBinContent.SetRange("Item No.", P_ItemNo);
        if L_DestBinContent.FindSet() then
            repeat
                L_TotalAvail += L_DestBinContent.CalcQtyAvailToTake(0);
            until L_DestBinContent.Next() = 0;
        exit(L_TotalAvail);
    end;

    local procedure GetActivityQtyToDestination(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]): Decimal
    var
        L_WhseActLine: Record "Warehouse Activity Line";
    begin
        // Qty already in flight via registered Movement documents (not yet posted) heading
        // into the destination zone. Treated as indirectly available toward Min. Qty.
        L_WhseActLine.SetRange("Activity Type", L_WhseActLine."Activity Type"::Movement);
        L_WhseActLine.SetRange("Action Type", L_WhseActLine."Action Type"::Place);
        L_WhseActLine.SetRange("Location Code", ReceiveLocation);
        L_WhseActLine.SetRange("Zone Code", P_ToZoneCode);
        L_WhseActLine.SetRange("Item No.", P_ItemNo);
        L_WhseActLine.CalcSums("Qty. Outstanding (Base)");
        exit(L_WhseActLine."Qty. Outstanding (Base)");
    end;

    local procedure GetActivityTotesToDestination(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]): Integer
    var
        L_ItemManufacturer: Record "Item Manufacturer Table";
        L_WhseActLine: Record "Warehouse Activity Line";
        L_MfgQtyBase: Decimal;
        L_Totes: Integer;
    begin
        // Per-manufacturer whole-tote count of in-flight Movement Place lines into destination.
        L_ItemManufacturer.SetRange("Item No", P_ItemNo);
        L_ItemManufacturer.SetFilter("Qty per Tote", '>%1', 0);
        if L_ItemManufacturer.FindSet() then
            repeat
                L_WhseActLine.Reset();
                L_WhseActLine.SetRange("Activity Type", L_WhseActLine."Activity Type"::Movement);
                L_WhseActLine.SetRange("Action Type", L_WhseActLine."Action Type"::Place);
                L_WhseActLine.SetRange("Location Code", ReceiveLocation);
                L_WhseActLine.SetRange("Zone Code", P_ToZoneCode);
                L_WhseActLine.SetRange("Item No.", P_ItemNo);
                L_WhseActLine.SetRange("Manufacturer Code", L_ItemManufacturer."Manufacturer Code");
                L_WhseActLine.CalcSums("Qty. Outstanding (Base)");
                L_MfgQtyBase := L_WhseActLine."Qty. Outstanding (Base)";
                if L_MfgQtyBase >= L_ItemManufacturer."Qty per Tote" then
                    L_Totes += Round(L_MfgQtyBase / L_ItemManufacturer."Qty per Tote", 1, '<');
            until L_ItemManufacturer.Next() = 0;
        exit(L_Totes);
    end;

    local procedure GetDestinationTotes(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]): Integer
    var
        L_ItemManufacturer: Record "Item Manufacturer Table";
        L_WhseEntry: Record "Warehouse Entry";
        L_MfgQtyBase: Decimal;
        L_Totes: Integer;
    begin
        // Totes already staged in the destination zone (Receive Location), counted per
        // manufacturer using each manufacturer's Qty per Tote. Partial-tote qty ignored.
        L_ItemManufacturer.SetRange("Item No", P_ItemNo);
        L_ItemManufacturer.SetFilter("Qty per Tote", '>%1', 0);
        if L_ItemManufacturer.FindSet() then
            repeat
                L_WhseEntry.Reset();
                L_WhseEntry.SetRange("Item No.", P_ItemNo);
                L_WhseEntry.SetRange("Location Code", ReceiveLocation);
                L_WhseEntry.SetRange("Zone Code", P_ToZoneCode);
                L_WhseEntry.SetRange("Manufacturer Code", L_ItemManufacturer."Manufacturer Code");
                L_WhseEntry.CalcSums("Qty. (Base)");
                L_MfgQtyBase := L_WhseEntry."Qty. (Base)";
                if L_MfgQtyBase >= L_ItemManufacturer."Qty per Tote" then
                    L_Totes += Round(L_MfgQtyBase / L_ItemManufacturer."Qty per Tote", 1, '>');
            until L_ItemManufacturer.Next() = 0;
        exit(L_Totes);
    end;

    local procedure GetPickBulkTotes(var P_BinContent: Record "Bin Content"): Integer
    var
        L_PickBulkQuery: Query Warehouse_Entry_Main;
        L_QtyPerTote: Decimal;
        L_Totes: Integer;
    begin
        // Sum warehouse entries per manufacturer inside the PICK BULK bin; count whole totes
        // using the manufacturer's Qty per Tote. Partial-tote quantities are ignored.
        L_PickBulkQuery.SetFilter(L_PickBulkQuery.Item_No_, '%1', P_BinContent."Item No.");
        L_PickBulkQuery.SetFilter(L_PickBulkQuery.Location_Code, '%1', P_BinContent."Location Code");
        L_PickBulkQuery.SetFilter(L_PickBulkQuery.Zone_Code, '%1', P_BinContent."Zone Code");
        L_PickBulkQuery.SetFilter(L_PickBulkQuery.Bin_Code, '%1', P_BinContent."Bin Code");
        L_PickBulkQuery.SetFilter(L_PickBulkQuery.Qty___Base_, '>%1', 0);
        L_PickBulkQuery.Open();
        while L_PickBulkQuery.Read() do begin
            L_QtyPerTote := GetQtyPerTote(P_BinContent."Item No.", L_PickBulkQuery.Manufacturer_Code);
            if L_QtyPerTote > 0 then
                if L_PickBulkQuery.Qty___Base_ >= L_QtyPerTote then
                    L_Totes += Round(L_PickBulkQuery.Qty___Base_ / L_QtyPerTote, 1, '>');
        end;
        L_PickBulkQuery.Close();
        exit(L_Totes);
    end;

    local procedure GetPendingTotesInWorksheet(P_ItemNo: Code[20]; P_ToZoneCode: Code[10]): Integer
    var
        L_ItemManufacturer: Record "Item Manufacturer Table";
        L_WhseWkshLine: Record "Whse. Worksheet Line";
        L_WhseItemTrackingLine: Record "Whse. Item Tracking Line";
        L_MfgQtyBase: Decimal;
        L_Totes: Integer;
    begin
        L_ItemManufacturer.SetRange("Item No", P_ItemNo);
        L_ItemManufacturer.SetFilter("Qty per Tote", '>%1', 0);
        if L_ItemManufacturer.FindSet() then
            repeat
                L_MfgQtyBase := 0;

                L_WhseWkshLine.SetRange("Worksheet Template Name", WhseWkshTemplateName);
                L_WhseWkshLine.SetRange(Name, WhseWkshName);
                L_WhseWkshLine.SetRange("Location Code", ReceiveLocation);
                L_WhseWkshLine.SetRange("From Zone Code", HighBayZone);
                L_WhseWkshLine.SetRange("To Zone Code", P_ToZoneCode);
                L_WhseWkshLine.SetRange("Item No.", P_ItemNo);
                if L_WhseWkshLine.FindSet() then
                    repeat
                        L_WhseItemTrackingLine.Reset();
                        L_WhseItemTrackingLine.SetRange("Source Type", DATABASE::"Whse. Worksheet Line");
                        L_WhseItemTrackingLine.SetRange("Source ID", L_WhseWkshLine.Name);
                        L_WhseItemTrackingLine.SetRange("Source Batch Name", L_WhseWkshLine."Worksheet Template Name");
                        L_WhseItemTrackingLine.SetRange("Source Ref. No.", L_WhseWkshLine."Line No.");
                        L_WhseItemTrackingLine.SetRange("Item No.", P_ItemNo);
                        L_WhseItemTrackingLine.SetRange("Manufacturer Code", L_ItemManufacturer."Manufacturer Code");
                        L_WhseItemTrackingLine.CalcSums("Quantity (Base)");
                        L_MfgQtyBase += L_WhseItemTrackingLine."Quantity (Base)";
                    until L_WhseWkshLine.Next() = 0;

                if L_MfgQtyBase >= L_ItemManufacturer."Qty per Tote" then
                    L_Totes += Round(L_MfgQtyBase / L_ItemManufacturer."Qty per Tote", 1, '>');
            until L_ItemManufacturer.Next() = 0;
        exit(L_Totes);
    end;

    local procedure GetQtyPerTote(P_ItemNo: Code[20]; P_ManufacturerCode: Code[10]): Decimal
    var
        L_ItemManufacturer: Record "Item Manufacturer Table";
    begin
        if P_ManufacturerCode = '' then
            exit(0);
        if L_ItemManufacturer.Get(P_ItemNo, P_ManufacturerCode) then
            exit(L_ItemManufacturer."Qty per Tote");
        exit(0);
    end;

    local procedure GetLotQtyAlreadyInWorksheet(P_ItemNo: Code[20]; P_LotNo: Code[50]): Decimal
    var
        L_WhseItemTrackingLine: Record "Whse. Item Tracking Line";
    begin
        L_WhseItemTrackingLine.SetRange("Source Type", DATABASE::"Whse. Worksheet Line");
        L_WhseItemTrackingLine.SetRange("Source ID", WhseWkshName);
        L_WhseItemTrackingLine.SetRange("Source Batch Name", WhseWkshTemplateName);
        L_WhseItemTrackingLine.SetRange("Location Code", ReceiveLocation);
        L_WhseItemTrackingLine.SetRange("Item No.", P_ItemNo);
        L_WhseItemTrackingLine.SetRange("Lot No.", P_LotNo);
        L_WhseItemTrackingLine.CalcSums("Quantity (Base)");
        exit(L_WhseItemTrackingLine."Quantity (Base)");
    end;

    local procedure InsertMovementWkshLine(var P_BinContent: Record "Bin Content"; P_LotNo: Code[50]; P_ExpirationDate: Date; P_UoMCode: Code[10]; P_QtyPerUoM: Decimal; P_MoveQtyBase: Decimal; P_ToZoneCode: Code[10]; P_ToBinCode: Code[20]; P_FromBinCode: Code[20]; P_ManufacturerCode: Code[10]; P_PackageNo: Code[50])
    var
        L_WhseWkshLine: Record "Whse. Worksheet Line";
        L_Item: Record Item;
    begin
        L_WhseWkshLine.Init();
        L_WhseWkshLine."Worksheet Template Name" := WhseWkshTemplateName;
        L_WhseWkshLine.Name := WhseWkshName;
        L_WhseWkshLine."Location Code" := ReceiveLocation;
        L_WhseWkshLine."Line No." := NextLineNo;

        L_WhseWkshLine.Validate("Item No.", P_BinContent."Item No.");

        L_WhseWkshLine."Unit of Measure Code" := P_UoMCode;
        if P_QtyPerUoM = 0 then
            P_QtyPerUoM := P_BinContent."Qty. per Unit of Measure";
        L_WhseWkshLine."Qty. per Unit of Measure" := P_QtyPerUoM;

        L_WhseWkshLine."From Zone Code" := HighBayZone;
        L_WhseWkshLine."From Bin Code" := P_FromBinCode;
        L_WhseWkshLine."To Zone Code" := P_ToZoneCode;
        L_WhseWkshLine."To Bin Code" := P_ToBinCode;

        L_WhseWkshLine.Validate(Quantity, P_MoveQtyBase / P_QtyPerUoM);
        if not DoNotFillQtytoHandle then
            L_WhseWkshLine.Validate("Qty. to Handle", P_MoveQtyBase / P_QtyPerUoM);

        if L_Item.Get(P_BinContent."Item No.") then
            L_WhseWkshLine.Description := L_Item.Description;

        L_WhseWkshLine.Insert(true);

        // Create Whse. Item Tracking Line for the lot
        InsertWhseItemTrackingLine(L_WhseWkshLine, P_LotNo, P_ExpirationDate, P_MoveQtyBase, P_ManufacturerCode, P_PackageNo);

        NextLineNo += 10000;
        LinesInserted += 1;
    end;

    local procedure InsertWhseItemTrackingLine(var P_WhseWkshLine: Record "Whse. Worksheet Line"; P_LotNo: Code[50]; P_ExpirationDate: Date; P_QtyBase: Decimal; P_ManufacturerCode: Code[10]; P_PackageNo: Code[50])
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
        L_WhseItemTrackingLine."Package No." := P_PackageNo;
        L_WhseItemTrackingLine."Manufacturer Code" := P_ManufacturerCode;

        L_WhseItemTrackingLine."Qty. per Unit of Measure" := P_WhseWkshLine."Qty. per Unit of Measure";
        L_WhseItemTrackingLine."Quantity (Base)" := P_QtyBase;
        L_WhseItemTrackingLine."Qty. to Handle (Base)" := P_QtyBase;

        L_WhseItemTrackingLine.Insert(true);
    end;
}
