Report 99971 "Cal _Bin Replenishment New"
{
    // Caption = 'Calculate Bin Replenishment';
    // ProcessingOnly = true;

    // dataset
    // {
    //     dataitem(Item; Item)
    //     {
    //         DataItemTableView = sorting("No.") order(descending);
    //         RequestFilterFields = "No.";

    //         trigger OnAfterGetRecord()
    //         begin
    //             //Calculate Available To Take Quantity++
    //             //Availabletotake := CodeUnit_ReplenishmentWorksheet.FindEmptyTotesAndCreateRepWorksheet("No.", LocationCode);
    //             FindEmptyTotesAndCreateRepWorksheet("No.", LocationCode);
    //         end;

    //         trigger OnPreDataItem()
    //         begin
    //             SetWhseWorksheet(WhseWkshTemplateName, WhseWkshName, LocationCode);
    //         end;
    //     }
    // }

    // requestpage
    // {
    //     SaveValues = true;

    //     layout
    //     {
    //         area(content)
    //         {
    //             group(Options)
    //             {
    //                 Caption = 'Options';
    //                 field(WorksheetTemplateName; WhseWkshTemplateName)
    //                 {
    //                     ApplicationArea = Warehouse;
    //                     Caption = 'Template Name';
    //                     TableRelation = "Whse. Worksheet Template";
    //                     ToolTip = 'Specifies the name of the template that applies to the movement lines.';
    //                     Editable = false;

    //                     trigger OnValidate()
    //                     begin
    //                         if WhseWkshTemplateName = '' then
    //                             WhseWkshName := '';
    //                     end;
    //                 }
    //                 field(WorksheetName; WhseWkshName)
    //                 {
    //                     ApplicationArea = Warehouse;
    //                     Caption = 'Batch Name';
    //                     Editable = false;
    //                 }
    //                 field(LocCode; LocationCode)
    //                 {
    //                     ApplicationArea = Warehouse;
    //                     Caption = 'Location Code';
    //                     TableRelation = Location;
    //                     Editable = false;
    //                 }
    //             }
    //         }
    //     }

    //     actions
    //     {
    //     }
    // }

    // labels
    // {
    // }

    // var
    //     WhseWorksheetName: Record "Whse. Worksheet Name";
    //     Text000: Label 'There is nothing to replenish.';
    //     WhseWkshTemplateName: Code[10];
    //     WhseWkshName: Code[10];
    //     HideDialog: Boolean;
    //     LocationCode: Code[10];
    //     Bin: Record Bin;
    //     MustNotBeErr: Label 'must not be %1.', Comment = '%1 - field value';
    //     //TempReplenishmentWorksheet: Record "Replenishment Worksheet" temporary; //Dont remove Temp property++
    //     BinType: Record "Bin Type";
    //     RemainQtyToReplenishBase: Decimal;
    //     NextLineNo: Integer;
    //     CodeUnit_ReplenishmentWorksheet: Codeunit "Replenishment Worksheet";
    //     TransferLineQty: Decimal;
    //     Availabletotake: Decimal;
    //     G_ReplenishmentWorksheet: Record "Replenishment Worksheet";

    // procedure InitializeRequest(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10]; HideDialog2: Boolean)
    // begin
    //     WhseWkshTemplateName := WhseWkshTemplateName2;
    //     WhseWkshName := WhseWkshName2;
    //     LocationCode := LocationCode2;
    //     HideDialog := HideDialog2;
    // end;



    // procedure FindEmptyTotesAndCreateRepWorksheet(_ItemNo: Code[20]; _LocationCode: Code[10]): Decimal
    // var
    //     L_WhseEntryMainQ: Query Warehouse_Entry_Main;
    //     L_WhseEntryDecantQ: Query WarehouseEntryDecant;
    //     L_Item: Record Item;

    //     L_ItemManufact: Record "Item Manufacturer Table";
    //     L_BinContent: Record "Bin Content";
    //     L_ExtraQty: Decimal;

    //     L_WhseEntry: Record "Warehouse Entry";
    //     L_ReplenishmentWorksheet1: Record "Replenishment Worksheet";

    //     L_RemQtyToMove: Decimal;
    // begin
    //     //L_WhseEntryMainQ.Close();

    //     L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Item_No_, '%1', _ItemNo);
    //     L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Location_Code, '%1', _LocationCode);
    //     L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Zone_Code, '%1', GetPickBulkZone(_LocationCode));
    //     L_WhseEntryMainQ.SetFilter(L_WhseEntryMainQ.Quantity, '%1', 0);
    //     L_WhseEntryMainQ.Open();
    //     while L_WhseEntryMainQ.Read() do begin
    //         L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Item_No_, '%1', L_WhseEntryMainQ.Item_No_);
    //         L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Location_Code, 'BULKNDPP');
    //         //L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Zone_Code, '%1', GetPickBulkZone('BULKNDPP'));
    //         L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Expiration_Date, '>=%1', WorkDate());
    //         L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Quantity, '>%1', 0);
    //         //L_WhseEntryDecantQ.TopNumberOfRows(1);
    //         L_WhseEntryDecantQ.Open();
    //         While L_WhseEntryDecantQ.Read() do begin
    //             //CreateReplenishmentWorksheet();

    //             L_ItemManufact.Reset();
    //             L_ItemManufact.SetRange("Item No", L_WhseEntryMainQ.Item_No_);
    //             L_ItemManufact.SetRange("Manufacturer code", L_WhseEntryDecantQ.Manufacturer_Code);
    //             if L_ItemManufact.FindFirst() then;

    //             L_BinContent.Reset();
    //             L_BinContent.SetRange("Item No.", L_WhseEntryMainQ.Item_No_);
    //             L_BinContent.SetRange("Location Code", L_WhseEntryMainQ.Location_Code);
    //             L_BinContent.SetRange("Zone Code", L_WhseEntryMainQ.Zone_Code);
    //             L_BinContent.SetRange("Bin Code", L_WhseEntryMainQ.Bin_Code);
    //             if L_BinContent.FindFirst() then;

    //             G_ReplenishmentWorksheet.Reset();
    //             G_ReplenishmentWorksheet.SetRange("Template Name", WhseWkshTemplateName);
    //             G_ReplenishmentWorksheet.SetRange("Batch Name", WhseWkshName);
    //             G_ReplenishmentWorksheet.SetRange("Item No.", L_WhseEntryMainQ.Item_No_);
    //             G_ReplenishmentWorksheet.SetRange("From Location Code", L_WhseEntryDecantQ.Location_Code);
    //             G_ReplenishmentWorksheet.SetRange("Location Code", L_WhseEntryMainQ.Location_Code);
    //             //G_ReplenishmentWorksheet.SetRange("Package No.", L_WhseEntryMainQ.Package_No_);
    //             if not G_ReplenishmentWorksheet.FindFirst() then begin

    //                 //Prathamesh++
    //                 G_ReplenishmentWorksheet.Init();
    //                 G_ReplenishmentWorksheet."Posting Date" := WorkDate();
    //                 G_ReplenishmentWorksheet."Template Name" := WhseWkshTemplateName;
    //                 G_ReplenishmentWorksheet."Batch Name" := WhseWkshName;
    //                 G_ReplenishmentWorksheet."Location Code" := L_WhseEntryMainQ.Location_Code;
    //                 G_ReplenishmentWorksheet."From Location Code" := L_WhseEntryDecantQ.Location_Code;
    //                 G_ReplenishmentWorksheet."From Bin Code" := L_WhseEntryDecantQ.Bin_Code;
    //                 G_ReplenishmentWorksheet."Line No." := NextLineNo;
    //                 G_ReplenishmentWorksheet."Item No." := L_WhseEntryDecantQ.Item_No_;
    //                 G_ReplenishmentWorksheet."Lot No." := L_WhseEntryDecantQ.Lot_No_;
    //                // G_ReplenishmentWorksheet."Package No." := L_WhseEntryMainQ.Package_No_;
    //                 G_ReplenishmentWorksheet."Expiration Date" := L_WhseEntryDecantQ.Expiration_Date;
    //                 L_Item.Reset();
    //                 L_Item.SetRange("No.", L_WhseEntryDecantQ.Item_No_);
    //                 if L_Item.FindFirst() then begin
    //                     G_ReplenishmentWorksheet.Description := L_Item.Description;
    //                 end;
    //                 G_ReplenishmentWorksheet."Totes in Bin" := L_BinContent."Number of Totes in a Bin";
    //                 G_ReplenishmentWorksheet."Maufacturer Tote Max Qty." := L_ItemManufact."Qty per Tote";
    //                 G_ReplenishmentWorksheet."System Quantity" := L_WhseEntryDecantQ.Quantity;
    //                 G_ReplenishmentWorksheet."Demand Quantity" := L_ItemManufact."Qty per Tote";

    //                 Clear(L_RemQtyToMove);
    //                 L_ReplenishmentWorksheet1.Reset();
    //                 L_ReplenishmentWorksheet1.SetRange("Item No.", L_WhseEntryDecantQ.Item_No_);
    //                 L_ReplenishmentWorksheet1.SetRange("From Location Code", L_WhseEntryDecantQ.Location_Code);
    //                 L_ReplenishmentWorksheet1.SetRange("From Bin Code", L_WhseEntryDecantQ.Bin_Code);
    //                 L_ReplenishmentWorksheet1.SetFilter("Lot No.", '%1', L_WhseEntryDecantQ.Lot_No_);
    //                 if L_ReplenishmentWorksheet1.FindSet() then begin
    //                     L_ReplenishmentWorksheet1.CalcSums("Qty to Move");
    //                     L_RemQtyToMove := L_WhseEntryDecantQ.Quantity - L_ReplenishmentWorksheet1."Qty to Move";
    //                 end else
    //                     L_RemQtyToMove := L_WhseEntryDecantQ.Quantity;

    //                 if L_RemQtyToMove <= L_ItemManufact."Qty per Tote" then
    //                     G_ReplenishmentWorksheet."Qty to Move" := L_RemQtyToMove
    //                 else begin
    //                     Clear(L_ExtraQty);
    //                     L_ExtraQty := L_RemQtyToMove - L_ItemManufact."Qty per Tote";

    //                     G_ReplenishmentWorksheet."Qty to Move" := L_RemQtyToMove - L_ExtraQty;
    //                 end;
    //                 G_ReplenishmentWorksheet.Action := G_ReplenishmentWorksheet.Action::Accept;
    //                 if L_RemQtyToMove > 0 then begin
    //                     G_ReplenishmentWorksheet.Insert();
    //                     L_WhseEntryDecantQ.Close();
    //                 end;

    //                 NextLineNo := NextLineNo + 10000;
    //             end;
    //             //Prathamesh--
    //         end;
    //         L_WhseEntryDecantQ.Close();
    //     end;
    //     L_WhseEntryMainQ.Close();
    //     //exit;

    //     // L_WhseEntry.Reset();
    //     // L_WhseEntry.SetRange("Item No.", Item."No.");
    //     // L_WhseEntry.SetRange("Location Code", _LocationCode);
    //     // if NOT L_WhseEntry.FindFirst() then begin
    //     //     L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Item_No_, '%1', Item."No.");
    //     //     L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Location_Code, 'BULKNDPP');
    //     //     L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Zone_Code, '%1', GetPickBulkZone('BULKNDPP'));
    //     //     L_WhseEntryDecantQ.SetFilter(L_WhseEntryDecantQ.Quantity, '>%1', 0);
    //     //     L_WhseEntryDecantQ.Open();
    //     //     While L_WhseEntryDecantQ.Read() do begin

    //     //     end;
    //     //     L_WhseEntryDecantQ.Close();
    //     // end;
    // end;

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

    // procedure SetWhseWorksheet(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10])
    // var
    //     ReplenishmentWorksheet: Record "Replenishment Worksheet";
    // begin
    //     ReplenishmentWorksheet.SetRange("Template Name", WhseWkshTemplateName2);
    //     ReplenishmentWorksheet.SetRange("Batch Name", WhseWkshName2);
    //     ReplenishmentWorksheet.SetRange("Location Code", LocationCode2);
    //     if ReplenishmentWorksheet.FindLast() then
    //         NextLineNo := ReplenishmentWorksheet."Line No." + 10000
    //     else
    //         NextLineNo := 10000;

    //     WhseWkshTemplateName := WhseWkshTemplateName2;
    //     WhseWkshName := WhseWkshName2;
    //     LocationCode := LocationCode2;
    // end;

    // // procedure CreateReplenishmentWorksheet()
    // // var
    // //     L_Item: Record Item;
    // // begin
    // //     G_ReplenishmentWorksheet.Init();
    // //     G_ReplenishmentWorksheet."Posting Date" := WorkDate();
    // //     G_ReplenishmentWorksheet."Template Name" := WhseWkshTemplateName;
    // //     G_ReplenishmentWorksheet."Batch Name" := WhseWkshName;
    // //     G_ReplenishmentWorksheet."Location Code" := ;
    // //     G_ReplenishmentWorksheet."From Location Code" := FromBinContent."Location Code";
    // //     G_ReplenishmentWorksheet."From Bin Code" := FromBinContent."Bin Code";
    // //     G_ReplenishmentWorksheet."Line No." := NextLineNo;
    // //     G_ReplenishmentWorksheet."Item No." := _ToReplenishment."Item No.";
    // //     L_Item.Reset();
    // //     L_Item.SetRange("No.", _ToReplenishment."Item No.");
    // //     if L_Item.FindFirst() then begin
    // //         G_ReplenishmentWorksheet.Description := L_Item.Description;
    // //         G_ReplenishmentWorksheet."Top Category" := L_Item."Top Category";
    // //     end;
    // //     G_ReplenishmentWorksheet."Variant Code" := FromBinContent."Variant Code"; //From Variant+++
    // //     G_ReplenishmentWorksheet."Min. Qty." := _ToReplenishment."Min Depot1 Qty";
    // //     G_ReplenishmentWorksheet."Max. Qty." := _ToReplenishment."Max Depot1 Qty";
    // //     G_ReplenishmentWorksheet."System Quantity" := Availabletotake;
    // //     G_ReplenishmentWorksheet."Demand Quantity" := _ToReplenishment."Max Depot1 Qty" - Availabletotake - TransferLineQty;
    // //     G_ReplenishmentWorksheet."Qty to Move" := MovementQtyBase;
    // //     G_ReplenishmentWorksheet.Action := G_ReplenishmentWorksheet.Action::Accept;
    // //     G_ReplenishmentWorksheet.Insert();

    // //     NextLineNo := NextLineNo + 10000;
    // // end;

}

