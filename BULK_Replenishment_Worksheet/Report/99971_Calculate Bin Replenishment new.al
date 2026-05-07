Report 99971 "Cal _Bin Replenishment New"
{
    Caption = 'Calculate Bin Replenishment';
    ProcessingOnly = true;

    dataset
    {
        dataitem(Item; Item)
        {
            DataItemTableView = sorting("No.") order(descending);
            RequestFilterFields = "No.";

            trigger OnAfterGetRecord()
            begin
                //Calculate Available To Take Quantity++
                //Availabletotake := CodeUnit_ReplenishmentWorksheet.FindEmptyTotesAndCreateRepWorksheet("No.", LocationCode);
                FindEmptyTotesAndCreateRepWorksheet("No.", LocationCode);
            end;

            trigger OnPreDataItem()
            begin
                Item.SetFilter("Routing Type", '%1', "Item Routing Type NDPP"::BULK);

                SetWhseWorksheet(WhseWkshTemplateName, WhseWkshName, LocationCode);
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
                        Caption = 'Template Name';
                        TableRelation = "Whse. Worksheet Template";
                        ToolTip = 'Specifies the name of the template that applies to the movement lines.';
                        Editable = false;

                        trigger OnValidate()
                        begin
                            if WhseWkshTemplateName = '' then
                                WhseWkshName := '';
                        end;
                    }
                    field(WorksheetName; WhseWkshName)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Batch Name';
                        Editable = false;
                    }
                    field(LocCode; LocationCode)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Location Code';
                        TableRelation = Location;
                        Editable = false;
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
        Text000: Label 'There is nothing to replenish.';
        WhseWkshTemplateName: Code[10];
        WhseWkshName: Code[10];
        HideDialog: Boolean;
        LocationCode: Code[10];
        Bin: Record Bin;
        MustNotBeErr: Label 'must not be %1.', Comment = '%1 - field value';
        //TempReplenishmentWorksheet: Record "Replenishment Worksheet" temporary; //Dont remove Temp property++
        BinType: Record "Bin Type";
        RemainQtyToReplenishBase: Decimal;
        NextLineNo: Integer;
        CodeUnit_ReplenishmentWorksheet: Codeunit "Replenishment Worksheet";
        TransferLineQty: Decimal;
        Availabletotake: Decimal;
        G_ReplenishmentWorksheet: Record "Replenishment Worksheet";

    procedure InitializeRequest(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10]; HideDialog2: Boolean)
    begin
        WhseWkshTemplateName := WhseWkshTemplateName2;
        WhseWkshName := WhseWkshName2;
        LocationCode := LocationCode2;
        HideDialog := HideDialog2;
    end;



    procedure FindEmptyTotesAndCreateRepWorksheet(_ItemNo: Code[20]; _LocationCode: Code[10])
    var
        L_SourceQ: Query WarehouseEntryReceive;
        L_Item: Record Item;
        L_BinContent: Record "Bin Content";
        L_PendingRepl: Record "Replenishment Worksheet";
        L_DupCheck: Record "Replenishment Worksheet";
        //L_Events: Codeunit Events;
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        L_ReceiveLocation: Code[20];
        L_ReceiveDecantZone: Code[20];
        //L_HighBayZone: Code[20];
        L_PickBulkZone: Code[20];
        L_CurrentQtyBase: Decimal;
        L_MinQtyBase: Decimal;
        L_MaxQtyBase: Decimal;
        L_RemQtyToReplenishBase: Decimal;
        L_AvailableSourceQtyBase: Decimal;
        L_QtyToTakeBase: Decimal;
        L_AlreadyAllocatedBase: Decimal;
        L_SourceQtyPerUoM: Decimal;
        L_BinQtyPerUoM: Decimal;
    begin
        L_ReceiveLocation := L_KamWhseSetupLookup.GetReceiveLocation();
        L_ReceiveDecantZone := L_KamWhseSetupLookup.GetBulkZone(L_ReceiveLocation);
        //L_HighBayZone := L_KamWhseSetupLookup.GetHighBayZone(L_ReceiveLocation);
        L_PickBulkZone := L_KamWhseSetupLookup.GetBulkZone(_LocationCode);

        // Iterate every PICK BULK Bin Content configured for this item (catches brand-new bins with no entries yet)
        L_BinContent.Reset();
        L_BinContent.SetRange("Item No.", _ItemNo);
        L_BinContent.SetRange("Location Code", _LocationCode);
        L_BinContent.SetRange("Zone Code", L_PickBulkZone);
        if L_BinContent.FindSet() then
            repeat
                // Current qty (base) in this destination bin (sums Warehouse Entry via FlowField)
                L_BinContent.CalcFields("Quantity (Base)");
                L_CurrentQtyBase := L_BinContent."Quantity (Base)";
                L_BinQtyPerUoM := L_BinContent."Qty. per Unit of Measure";
                if L_BinQtyPerUoM = 0 then
                    L_BinQtyPerUoM := 1;
                L_MinQtyBase := L_BinContent."Min. Qty." * L_BinQtyPerUoM;
                L_MaxQtyBase := L_BinContent."Max. Qty." * L_BinQtyPerUoM;

                // Trigger replenishment only when below Min Qty AND there is room up to Max Qty (base)
                if (L_CurrentQtyBase <= L_MinQtyBase) and
                   (L_MaxQtyBase > L_CurrentQtyBase)
                then begin
                    L_RemQtyToReplenishBase := L_MaxQtyBase - L_CurrentQtyBase;

                    // Source: BULK location, BULK DECANT or HIGHBAY zones, FEFO (query is ordered by Expiration_Date asc)
                    L_SourceQ.SetFilter(L_SourceQ.Item_No_, '%1', _ItemNo);
                    L_SourceQ.SetFilter(L_SourceQ.Location_Code, '%1', L_ReceiveLocation);
                    // L_SourceQ.SetFilter(L_SourceQ.Zone_Code, '%1|%2', L_BulkDecantZone, L_HighBayZone);
                    L_SourceQ.SetFilter(L_SourceQ.Zone_Code, '%1', L_ReceiveDecantZone);
                    L_SourceQ.SetFilter(L_SourceQ.Expiration_Date, '>=%1', WorkDate());
                    L_SourceQ.SetFilter(L_SourceQ.Qty_Base, '>%1', 0);
                    L_SourceQ.SetFilter(L_SourceQ.Manufacturer_Code, '<>%1', '');
                    L_SourceQ.Open();
                    while (L_RemQtyToReplenishBase > 0) and L_SourceQ.Read() do begin
                        // Skip if a worksheet line already exists for this exact source-lot/destination pair
                        L_DupCheck.Reset();
                        L_DupCheck.SetRange("Template Name", WhseWkshTemplateName);
                        L_DupCheck.SetRange("Batch Name", WhseWkshName);
                        L_DupCheck.SetRange("Item No.", L_SourceQ.Item_No_);
                        L_DupCheck.SetRange("From Location Code", L_SourceQ.Location_Code);
                        L_DupCheck.SetRange("From Bin Code", L_SourceQ.Bin_Code);
                        L_DupCheck.SetRange("Lot No.", L_SourceQ.Lot_No_);
                        L_DupCheck.SetRange("Location Code", L_BinContent."Location Code");
                        L_DupCheck.SetRange("Bin Code", L_BinContent."Bin Code");
                        if L_DupCheck.IsEmpty() then begin
                            // Subtract qty already allocated (base) from this source bin/lot in the worksheet
                            Clear(L_AlreadyAllocatedBase);
                            L_SourceQtyPerUoM := L_SourceQ.Qty_per_Unit_of_Measure;
                            if L_SourceQtyPerUoM = 0 then
                                L_SourceQtyPerUoM := 1;
                            L_PendingRepl.Reset();
                            L_PendingRepl.SetRange("Item No.", L_SourceQ.Item_No_);
                            L_PendingRepl.SetRange("From Location Code", L_SourceQ.Location_Code);
                            L_PendingRepl.SetRange("From Bin Code", L_SourceQ.Bin_Code);
                            L_PendingRepl.SetRange("Lot No.", L_SourceQ.Lot_No_);
                            if not L_PendingRepl.IsEmpty() then begin
                                L_PendingRepl.CalcSums("Qty to Move");
                                L_AlreadyAllocatedBase := L_PendingRepl."Qty to Move" * L_SourceQtyPerUoM;
                            end;

                            L_AvailableSourceQtyBase := L_SourceQ.Qty_Base - L_AlreadyAllocatedBase;
                            if L_AvailableSourceQtyBase > 0 then begin
                                if L_AvailableSourceQtyBase >= L_RemQtyToReplenishBase then
                                    L_QtyToTakeBase := L_RemQtyToReplenishBase
                                else
                                    L_QtyToTakeBase := L_AvailableSourceQtyBase;

                                G_ReplenishmentWorksheet.Init();
                                G_ReplenishmentWorksheet."Posting Date" := WorkDate();
                                G_ReplenishmentWorksheet."Template Name" := WhseWkshTemplateName;
                                G_ReplenishmentWorksheet."Batch Name" := WhseWkshName;
                                G_ReplenishmentWorksheet."Line No." := NextLineNo;
                                G_ReplenishmentWorksheet."Item No." := L_SourceQ.Item_No_;
                                if L_Item.Get(L_SourceQ.Item_No_) then
                                    G_ReplenishmentWorksheet.Description := L_Item.Description;
                                G_ReplenishmentWorksheet."Manufacturer Code" := L_SourceQ.Manufacturer_Code;
                                G_ReplenishmentWorksheet."Variant Code" := L_SourceQ.Variant_Code;
                                G_ReplenishmentWorksheet."Unit of Measure Code" := L_SourceQ.Unit_of_Measure_Code;
                                G_ReplenishmentWorksheet."From Location Code" := L_SourceQ.Location_Code;
                                G_ReplenishmentWorksheet."From Bin Code" := L_SourceQ.Bin_Code;
                                G_ReplenishmentWorksheet."Location Code" := L_BinContent."Location Code";
                                G_ReplenishmentWorksheet."Bin Code" := L_BinContent."Bin Code";
                                G_ReplenishmentWorksheet."Lot No." := L_SourceQ.Lot_No_;
                                G_ReplenishmentWorksheet."Package No." := L_SourceQ.Package_No_;
                                G_ReplenishmentWorksheet."Expiration Date" := L_SourceQ.Expiration_Date;
                                G_ReplenishmentWorksheet."Min. Qty." := L_BinContent."Min. Qty.";
                                G_ReplenishmentWorksheet."Max. Qty." := L_BinContent."Max. Qty.";
                                G_ReplenishmentWorksheet."System Quantity" := L_CurrentQtyBase / L_BinQtyPerUoM;
                                G_ReplenishmentWorksheet."Available Qty" := L_AvailableSourceQtyBase / L_SourceQtyPerUoM;
                                G_ReplenishmentWorksheet."Demand Quantity" := (L_MaxQtyBase - L_CurrentQtyBase) / L_BinQtyPerUoM;
                                G_ReplenishmentWorksheet."Qty to Move" := L_QtyToTakeBase / L_SourceQtyPerUoM;
                                G_ReplenishmentWorksheet.Action := G_ReplenishmentWorksheet.Action::Accept;
                                G_ReplenishmentWorksheet.Insert();

                                NextLineNo := NextLineNo + 10000;
                                L_RemQtyToReplenishBase := L_RemQtyToReplenishBase - L_QtyToTakeBase;
                            end;
                        end;
                    end;
                    L_SourceQ.Close();
                end;
            until L_BinContent.Next() = 0;
    end;

    // local procedure GetPickBulkZone(P_LocationCode: Code[10]): Code[10]
    // var
    //     L_Zone: Record Zone;
    // begin
    //     L_Zone.Reset();
    //     L_Zone.SetRange("Location Code", P_LocationCode);
    //     L_Zone.SetFilter(L_Zone.BULK, '%1', true);
    //     if L_Zone.FindFirst() then
    //         exit(L_Zone.Code);
    // end;

    procedure SetWhseWorksheet(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10])
    var
        ReplenishmentWorksheet: Record "Replenishment Worksheet";
    begin
        ReplenishmentWorksheet.SetRange("Template Name", WhseWkshTemplateName2);
        ReplenishmentWorksheet.SetRange("Batch Name", WhseWkshName2);
        ReplenishmentWorksheet.SetRange("Location Code", LocationCode2);
        if ReplenishmentWorksheet.FindLast() then
            NextLineNo := ReplenishmentWorksheet."Line No." + 10000
        else
            NextLineNo := 10000;

        WhseWkshTemplateName := WhseWkshTemplateName2;
        WhseWkshName := WhseWkshName2;
        LocationCode := LocationCode2;
    end;

    // procedure CreateReplenishmentWorksheet()
    // var
    //     L_Item: Record Item;
    // begin
    //     G_ReplenishmentWorksheet.Init();
    //     G_ReplenishmentWorksheet."Posting Date" := WorkDate();
    //     G_ReplenishmentWorksheet."Template Name" := WhseWkshTemplateName;
    //     G_ReplenishmentWorksheet."Batch Name" := WhseWkshName;
    //     G_ReplenishmentWorksheet."Location Code" := ;
    //     G_ReplenishmentWorksheet."From Location Code" := FromBinContent."Location Code";
    //     G_ReplenishmentWorksheet."From Bin Code" := FromBinContent."Bin Code";
    //     G_ReplenishmentWorksheet."Line No." := NextLineNo;
    //     G_ReplenishmentWorksheet."Item No." := _ToReplenishment."Item No.";
    //     L_Item.Reset();
    //     L_Item.SetRange("No.", _ToReplenishment."Item No.");
    //     if L_Item.FindFirst() then begin
    //         G_ReplenishmentWorksheet.Description := L_Item.Description;
    //         G_ReplenishmentWorksheet."Top Category" := L_Item."Top Category";
    //     end;
    //     G_ReplenishmentWorksheet."Variant Code" := FromBinContent."Variant Code"; //From Variant+++
    //     G_ReplenishmentWorksheet."Min. Qty." := _ToReplenishment."Min Depot1 Qty";
    //     G_ReplenishmentWorksheet."Max. Qty." := _ToReplenishment."Max Depot1 Qty";
    //     G_ReplenishmentWorksheet."System Quantity" := Availabletotake;
    //     G_ReplenishmentWorksheet."Demand Quantity" := _ToReplenishment."Max Depot1 Qty" - Availabletotake - TransferLineQty;
    //     G_ReplenishmentWorksheet."Qty to Move" := MovementQtyBase;
    //     G_ReplenishmentWorksheet.Action := G_ReplenishmentWorksheet.Action::Accept;
    //     G_ReplenishmentWorksheet.Insert();

    //     NextLineNo := NextLineNo + 10000;
    // end;

}

