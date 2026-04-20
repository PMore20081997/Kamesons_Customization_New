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
                Item.SetFilter(Bulk, '%1', true);

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
        L_Events: Codeunit Events;
        L_BulkLocation: Code[20];
        L_BulkDecantZone: Code[20];
        L_HighBayZone: Code[20];
        L_PickBulkZone: Code[20];
        L_CurrentQty: Decimal;
        L_RemQtyToReplenish: Decimal;
        L_AvailableSourceQty: Decimal;
        L_QtyToTake: Decimal;
        L_AlreadyAllocated: Decimal;
    begin
        L_BulkLocation := L_Events.GetReceiveWarehouse();
        L_BulkDecantZone := L_Events.GetReceiveBulkZone(L_BulkLocation);
        L_HighBayZone := L_Events.GetPickHighBayZone(L_BulkLocation);
        L_PickBulkZone := L_Events.GetPickBulkZone(_LocationCode);

        // Iterate every PICK BULK Bin Content configured for this item (catches brand-new bins with no entries yet)
        L_BinContent.Reset();
        L_BinContent.SetRange("Item No.", _ItemNo);
        L_BinContent.SetRange("Location Code", _LocationCode);
        L_BinContent.SetRange("Zone Code", L_PickBulkZone);
        if L_BinContent.FindSet() then
            repeat
                // Current qty in this destination bin (sums Warehouse Entry via FlowField)
                L_BinContent.CalcFields(Quantity);
                L_CurrentQty := L_BinContent.Quantity;

                // Trigger replenishment only when below Min Qty AND there is room up to Max Qty
                if (L_CurrentQty <= L_BinContent."Min. Qty.") and
                   (L_BinContent."Max. Qty." > L_CurrentQty)
                then begin
                    L_RemQtyToReplenish := L_BinContent."Max. Qty." - L_CurrentQty;

                    // Source: BULK location, BULK DECANT or HIGHBAY zones, FEFO (query is ordered by Expiration_Date asc)
                    L_SourceQ.SetFilter(L_SourceQ.Item_No_, '%1', _ItemNo);
                    L_SourceQ.SetFilter(L_SourceQ.Location_Code, '%1', L_BulkLocation);
                    L_SourceQ.SetFilter(L_SourceQ.Zone_Code, '%1|%2', L_BulkDecantZone, L_HighBayZone);
                    L_SourceQ.SetFilter(L_SourceQ.Expiration_Date, '>=%1', WorkDate());
                    L_SourceQ.SetFilter(L_SourceQ.Quantity, '>%1', 0);
                    L_SourceQ.Open();
                    while (L_RemQtyToReplenish > 0) and L_SourceQ.Read() do begin
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
                            // Subtract qty already allocated from this source bin/lot in the worksheet
                            Clear(L_AlreadyAllocated);
                            L_PendingRepl.Reset();
                            L_PendingRepl.SetRange("Item No.", L_SourceQ.Item_No_);
                            L_PendingRepl.SetRange("From Location Code", L_SourceQ.Location_Code);
                            L_PendingRepl.SetRange("From Bin Code", L_SourceQ.Bin_Code);
                            L_PendingRepl.SetRange("Lot No.", L_SourceQ.Lot_No_);
                            if not L_PendingRepl.IsEmpty() then begin
                                L_PendingRepl.CalcSums("Qty to Move");
                                L_AlreadyAllocated := L_PendingRepl."Qty to Move";
                            end;

                            L_AvailableSourceQty := L_SourceQ.Quantity - L_AlreadyAllocated;
                            if L_AvailableSourceQty > 0 then begin
                                if L_AvailableSourceQty >= L_RemQtyToReplenish then
                                    L_QtyToTake := L_RemQtyToReplenish
                                else
                                    L_QtyToTake := L_AvailableSourceQty;

                                G_ReplenishmentWorksheet.Init();
                                G_ReplenishmentWorksheet."Posting Date" := WorkDate();
                                G_ReplenishmentWorksheet."Template Name" := WhseWkshTemplateName;
                                G_ReplenishmentWorksheet."Batch Name" := WhseWkshName;
                                G_ReplenishmentWorksheet."Line No." := NextLineNo;
                                G_ReplenishmentWorksheet."Item No." := L_SourceQ.Item_No_;
                                if L_Item.Get(L_SourceQ.Item_No_) then
                                    G_ReplenishmentWorksheet.Description := L_Item.Description;
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
                                G_ReplenishmentWorksheet."System Quantity" := L_CurrentQty;
                                G_ReplenishmentWorksheet."Available Qty" := L_AvailableSourceQty;
                                G_ReplenishmentWorksheet."Demand Quantity" := L_BinContent."Max. Qty." - L_CurrentQty;
                                G_ReplenishmentWorksheet."Qty to Move" := L_QtyToTake;
                                G_ReplenishmentWorksheet.Action := G_ReplenishmentWorksheet.Action::Accept;
                                G_ReplenishmentWorksheet.Insert();

                                NextLineNo := NextLineNo + 10000;
                                L_RemQtyToReplenish := L_RemQtyToReplenish - L_QtyToTake;
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

