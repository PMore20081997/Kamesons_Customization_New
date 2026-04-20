codeunit 99983 "Event Subscribers NDPP"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Put-away", OnBeforeWhseActivLineInsert, '', false, false)]
    local procedure OnBeforeWhseActivLineInsert(var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        L_Item: Record Item;
        L_Zone: Record Zone;
        L_BinContent: Record "Bin Content";
        L_BulkDecntExpDate: Date;

    begin
        if WarehouseActivityLine."Location Code" <> G_Events.GetReceiveWarehouse() then
            exit;  //Temporary++

        if (WarehouseActivityLine."Activity Type" <> WarehouseActivityLine."Activity Type"::"Put-away") OR (WarehouseActivityLine."Action Type" <> WarehouseActivityLine."Action Type"::Place) OR (WarehouseActivityLine."Source Document" <> WarehouseActivityLine."Source Document"::"Purchase Order") then
            exit;

        L_Item.SetLoadFields(BULK);
        if not L_Item.Get(WarehouseActivityLine."Item No.") then
            exit;


        Clear(L_BulkDecntExpDate);
        IF L_Item.BULK = true then begin
            L_BulkDecntExpDate := GetLastExpiryDateInBulkDecant(WarehouseActivityLine);

            if L_BulkDecntExpDate = 0D then begin
                AssignZoneBin(WarehouseActivityLine, true);
            end else if WarehouseActivityLine."Expiration Date" <= L_BulkDecntExpDate then begin
                AssignZoneBin(WarehouseActivityLine, true);
            end else
                AssignZoneBin(WarehouseActivityLine, false);
        end
        else begin
            AssignZoneBin(WarehouseActivityLine, false);
        end;

        L_Zone.Get(WarehouseActivityLine."Location Code", WarehouseActivityLine."Zone Code");

        if L_Zone.HighBay then
            exit;


        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', G_Events.GetMainWarehouse());
        L_BinContent.SetFilter("Zone Code", '%1', G_Events.GetPickBulkZone(G_Events.GetMainWarehouse()));
        L_BinContent.SetRange("Item No.", WarehouseActivityLine."Item No.");
        if L_BinContent.FindFirst() then begin
            L_BinContent.CalcFields(Quantity, "Put-away Qty.", "Pos. Adjmt. Qty.");

            Clear(G_BinContentQty);
            G_BinContentQty := L_BinContent.Quantity + L_BinContent."Put-away Qty." + L_BinContent."Pos. Adjmt. Qty.";
        end;
    end;


    procedure GetLastExpiryDateInBulkDecant(var P_WhseActLine: Record "Warehouse Activity Line"): Date
    var
        L_WarehouseEntryLotDetails: Query WarehouseEntryLotDetails;
        L_MainStockExpDate: Date;
        L_BulkDecntStockExpDate: Date;
    begin
        //Get Last Expiry BULNDPP BULK DECNT
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Item_No_, '%1', P_WhseActLine."Item No.");
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Location_Code, '%1', G_Events.GetReceiveWarehouse());
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Zone_Code, '%1', G_Events.GetReceiveBulkZone(G_Events.GetReceiveWarehouse()));
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Quantity, '>%1', 0);
        L_WarehouseEntryLotDetails.TopNumberOfRows(1);
        L_WarehouseEntryLotDetails.Open();
        while L_WarehouseEntryLotDetails.Read() do begin
            L_BulkDecntStockExpDate := L_WarehouseEntryLotDetails.Expiration_Date;
        end;
        L_WarehouseEntryLotDetails.Close();

        exit(L_BulkDecntStockExpDate);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterInsertEvent, '', false, false)]
    local procedure OnAfterInsertEventWAL(var Rec: Record "Warehouse Activity Line")
    var
        L_BinContent: Record "Bin Content";
        L_WhseActivLine: Record "Warehouse Activity Line";
        L_Zone: Record Zone;
    begin
        if Rec."Location Code" <> G_Events.GetReceiveWarehouse() then
            exit; //Temporary++

        If L_Zone.Get(Rec."Location Code", Rec."Zone Code") then;



        if (Rec."Activity Type" <> Rec."Activity Type"::"Put-away") OR (Rec."Action Type" <> Rec."Action Type"::Place) OR (Rec."Source Document" <> Rec."Source Document"::"Purchase Order") OR (L_Zone.HighBay) then
            exit;


        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', G_Events.GetMainWarehouse());
        L_BinContent.SetFilter("Zone Code", '%1', G_Events.GetPickBulkZone(G_Events.GetMainWarehouse()));
        L_BinContent.SetRange("Item No.", Rec."Item No.");
        if L_BinContent.FindFirst() then begin

            if (L_BinContent."Max. Qty." > 0) AND ((G_BinContentQty + Rec.Quantity) > L_BinContent."Max. Qty.") then begin

                Clear(G_SplitQtyToHandle);

                G_SplitQtyToHandle := L_BinContent."Max. Qty." - G_BinContentQty;

                if G_SplitQtyToHandle > 0 then begin
                    Rec.Validate("Qty. to Handle", G_SplitQtyToHandle);
                    Rec.Modify();

                    G_IsExecuting := false;

                    L_WhseActivLine.Copy(Rec);
                    G_LineSpacing := true;

                    Rec.SplitLine(L_WhseActivLine);
                    Rec.Copy(L_WhseActivLine);

                    G_LineSpacing := false;
                end else begin
                    G_IsExecuting := false;

                    AssignZoneBin(Rec, false);
                    Rec.Modify();
                end;
            end;
        end;

        Clear(G_BinContentQty); //Test++
    end;

    local procedure AssignZoneBin(var P_WarehouseActivityLine: Record "Warehouse Activity Line"; IsBulk: Boolean)
    var
        L_BinContent: Record "Bin Content";
        L_Zone: Record Zone;
    begin
        L_Zone.Reset();
        L_Zone.SetRange("Location Code", P_WarehouseActivityLine."Location Code");
        if IsBulk then
            L_Zone.SetFilter(BULK, '%1', true)
        else
            L_Zone.SetFilter(HighBay, '%1', true);
        if not L_Zone.FindFirst() then
            exit;

        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', P_WarehouseActivityLine."Location Code");
        L_BinContent.SetFilter("Zone Code", '%1', L_Zone.Code);
        L_BinContent.SetRange("Item No.", P_WarehouseActivityLine."Item No.");
        if L_BinContent.FindFirst() then begin

            P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
            P_WarehouseActivityLine.Validate("Bin Code", L_BinContent."Bin Code");
        end
        else
            P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Post Receipt", OnCreatePutAwayDocOnBeforeCreatePutAwayRun, '', false, false)]
    local procedure OnCreatePutAwayDocOnBeforeCreatePutAwayRun()
    begin
        Clear(G_IsExecuting);
        G_IsExecuting := true;
    end;



    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnBeforeInsertNewWhseActivLine, '', false, false)]
    local procedure OnBeforeInsertNewWhseActivLine(var NewWarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        AssignZoneBin(NewWarehouseActivityLine, false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnSplitLineOnBeforeRenumberAllLines, '', false, false)]
    local procedure OnSplitLineOnBeforeRenumberAllLines(var LineSpacing: Integer)
    begin
        if G_LineSpacing then
            LineSpacing := 5000;
    end;

    var
        G_SplitQtyToHandle: Decimal;
        G_IsExecuting: Boolean;
        G_LineSpacing: Boolean;
        G_BinContentQty: Decimal;
        G_Events: Codeunit Events;
        G_Bin: Record Bin;
}
