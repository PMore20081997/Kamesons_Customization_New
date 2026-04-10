Report 99972 "Cal _Movement Worksheet"
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



    procedure FindEmptyTotesAndCreateRepWorksheet(_ItemNo: Code[20]; _LocationCode: Code[10]): Decimal
    var
        L_WhseEntryMainQ: Query Warehouse_Entry_Main;
        L_WhseEntryDecantQ: Query WarehouseEntryDecant;
        L_Item: Record Item;
        L_ItemManufact: Record "Item Manufacturer Table";
        L_BinContent: Record "Bin Content";
        L_ExtraQty: Decimal;
        L_WhseEntry: Record "Warehouse Entry";
        L_ReplenishmentWorksheet1: Record "Replenishment Worksheet";
        L_TotalReqQtyToMain: Decimal;

        L_Events: Codeunit Events;
    begin
        L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Item_No_, '%1', _ItemNo);
        L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Location_Code, '%1', _LocationCode);
        L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Zone_Code, '%1', L_Events.GetPickBulkZone(_LocationCode));
        L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Quantity, '%1', 0);
        L_WhseEntryMainQ.Open();
        while L_WhseEntryMainQ.Read() do begin
            If CheckAvailableQtyLessThanMinQtyinMAIN(L_WhseEntryMainQ.Item_No_) then begin
                L_BinContent.Reset();
                L_BinContent.SetRange("Item No.", _ItemNo);
                L_BinContent.SetFilter("Location Code", '%1', 'MAIN');
                L_BinContent.SetFilter("Bin Code", '%1', 'PICK BULK');
                L_BinContent.SetFilter(Quantity, '>%1', 0);
                if L_BinContent.FindFirst() then begin
                    Clear(L_TotalReqQtyToMain);
                    L_TotalReqQtyToMain := L_BinContent."Max. Qty." - L_BinContent.CalcQtyAvailToTake(0);
                end;

                L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Item_No_, '%1', L_WhseEntryMainQ.Item_No_);
                L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Location_Code, 'BULKNDPP');
                L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Zone_Code, '%1', L_Events.GetPickBulkZone('BULKNDPP'));
                L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Expiration_Date, '>=%1', WorkDate());
                L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Quantity, '>%1', 0);
                L_WhseEntryDecantQ.Open();
                While L_WhseEntryDecantQ.Read() do begin

                end;
            end;
        end;
        L_WhseEntryMainQ.Close();
    end;



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

    procedure CheckAvailableQtyLessThanMinQtyinMAIN(P_ItemNo: Code[20]): Boolean
    var
        L_MainBinContent: Record "Bin Content";
        L_MainQtyAvailToTake: Decimal;
    begin
        Clear(L_MainQtyAvailToTake);
        L_MainBinContent.Reset();
        L_MainBinContent.SetRange("Item No.", P_ItemNo);
        L_MainBinContent.SetFilter("Location Code", '%1', 'MAIN');
        L_MainBinContent.SetFilter("Bin Code", '%1', 'PICK BULK');
        L_MainBinContent.SetFilter(Quantity, '>%1', 0);
        if L_MainBinContent.FindFirst() then begin

            L_MainQtyAvailToTake := L_MainBinContent.CalcQtyAvailToTake(0);
        end;

        if L_MainQtyAvailToTake < L_MainBinContent."Min. Qty." then
            exit(true)
        else
            exit(false);
    end;

    var
        G_EventSubscribersNDPP: Codeunit "Event Subscribers NDPP";
}

