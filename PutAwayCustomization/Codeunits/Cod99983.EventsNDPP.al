codeunit 99983 "Event Subscribers NDPP"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Put-away", OnBeforeWhseActivLineInsert, '', false, false)]
    local procedure OnBeforeWhseActivLineInsert(var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        L_Item: Record Item;
        L_Zone: Record Zone;
        L_LastExpiry: Date;
        L_DecantZoneCode: Code[10];
        L_TargetZone: Option BulkDecant,GenDecant,HighBay;
    begin
        if WarehouseActivityLine."Location Code" <> G_Events.GetReceiveWarehouse() then
            exit;

        if (WarehouseActivityLine."Activity Type" <> WarehouseActivityLine."Activity Type"::"Put-away") OR (WarehouseActivityLine."Action Type" <> WarehouseActivityLine."Action Type"::Place) OR (WarehouseActivityLine."Source Document" <> WarehouseActivityLine."Source Document"::"Purchase Order") then
            exit;

        L_Item.SetLoadFields(BULK);
        if not L_Item.Get(WarehouseActivityLine."Item No.") then
            exit;

        L_Zone.Get(WarehouseActivityLine."Location Code", WarehouseActivityLine."Zone Code");
        // if L_Zone.HighBay OR L_Zone.General OR L_Zone.BULK then
        //     exit;
        if L_Zone.HighBay then
            exit;

        if L_Item.BULK then begin
            L_TargetZone := L_TargetZone::BulkDecant;
            L_DecantZoneCode := G_Events.GetBulkZone(G_Events.GetReceiveWarehouse());
        end else begin
            L_TargetZone := L_TargetZone::GenDecant;
            L_DecantZoneCode := G_Events.GetGenDecantZone(G_Events.GetReceiveWarehouse());
        end;

        L_LastExpiry := GetLastExpiryDate(WarehouseActivityLine, L_DecantZoneCode);

        Clear(G_BinContentQty);
        if (L_LastExpiry = 0D) OR (WarehouseActivityLine."Expiration Date" <= L_LastExpiry) then begin
            AssignZoneBin(WarehouseActivityLine, L_TargetZone);
            G_BinContentQty := CalcPickBulkReservedQty(WarehouseActivityLine."Item No.", L_DecantZoneCode);
        end else
            AssignZoneBin(WarehouseActivityLine, L_TargetZone::HighBay);
    end;

    procedure GetLastExpiryDate(var P_WhseActLine: Record "Warehouse Activity Line"; P_ZoneCode: Code[10]): Date
    var
        L_WarehouseEntryLotDetails: Query WarehouseEntryLotDetails;
        L_DecantStockExpDate: Date;
    begin
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Item_No_, '%1', P_WhseActLine."Item No.");
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Location_Code, '%1', G_Events.GetReceiveWarehouse());
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Zone_Code, '%1', P_ZoneCode);
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Quantity, '>%1', 0);
        L_WarehouseEntryLotDetails.TopNumberOfRows(1);
        L_WarehouseEntryLotDetails.Open();
        while L_WarehouseEntryLotDetails.Read() do
            L_DecantStockExpDate := L_WarehouseEntryLotDetails.Expiration_Date;
        L_WarehouseEntryLotDetails.Close();

        exit(L_DecantStockExpDate);
    end;

    local procedure CalcPickBulkReservedQty(P_ItemNo: Code[20]; P_DecantZoneCode: Code[10]): Decimal
    var
        L_BinContent: Record "Bin Content";
        L_WhseActLine: Record "Warehouse Activity Line";
        L_Total: Decimal;
    begin
        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', G_Events.GetMainWarehouse());
        L_BinContent.SetFilter("Zone Code", '%1', G_Events.GetBulkZone(G_Events.GetMainWarehouse()));
        L_BinContent.SetRange("Item No.", P_ItemNo);
        if not L_BinContent.FindFirst() then
            exit(0);

        L_BinContent.CalcFields(Quantity, "Put-away Qty.", "Pos. Adjmt. Qty.");

        L_WhseActLine.Reset();
        L_WhseActLine.SetRange("Action Type", L_WhseActLine."Action Type"::Place);
        L_WhseActLine.SetRange("Item No.", P_ItemNo);
        L_WhseActLine.SetFilter("Location Code", '%1', G_Events.GetReceiveWarehouse());
        L_WhseActLine.SetFilter("Zone Code", '%1', P_DecantZoneCode);
        if L_WhseActLine.FindSet() then
            L_WhseActLine.CalcSums("Qty. Outstanding (Base)");

        L_Total := L_BinContent."Quantity (Base)" + L_WhseActLine."Qty. Outstanding (Base)" + L_BinContent."Put-away Quantity (Base)" + L_BinContent."Positive Adjmt. Qty. (Base)";
        exit(L_Total);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterInsertEvent, '', false, false)]
    local procedure OnAfterInsertEventWAL(var Rec: Record "Warehouse Activity Line")
    var
        L_BinContent: Record "Bin Content";
        L_WhseActivLine: Record "Warehouse Activity Line";
        L_Zone: Record Zone;
    begin
        if Rec."Location Code" <> G_Events.GetReceiveWarehouse() then
            exit;

        if not L_Zone.Get(Rec."Location Code", Rec."Zone Code") then
            exit;

        if (Rec."Activity Type" <> Rec."Activity Type"::"Put-away") OR (Rec."Action Type" <> Rec."Action Type"::Place) OR (Rec."Source Document" <> Rec."Source Document"::"Purchase Order") OR L_Zone.HighBay then
            exit;

        if not (L_Zone.BULK OR L_Zone.General) then
            exit;

        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', G_Events.GetMainWarehouse());
        if L_Zone.BULK then
            L_BinContent.SetFilter("Zone Code", '%1', G_Events.GetBulkZone(G_Events.GetMainWarehouse()));
        if L_Zone.General then
            L_BinContent.SetFilter("Zone Code", '%1', G_Events.GetGenDecantZone(G_Events.GetMainWarehouse()));
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
                    AssignZoneBin(Rec, 2);
                    Rec.Modify();
                end;
            end;
        end;

        Clear(G_BinContentQty);
    end;

    local procedure AssignZoneBin(var P_WarehouseActivityLine: Record "Warehouse Activity Line"; P_ZoneType: Option BulkDecant,GenDecant,HighBay)
    var
        L_BinContent: Record "Bin Content";
        L_Zone: Record Zone;
    begin
        L_Zone.Reset();
        L_Zone.SetRange("Location Code", P_WarehouseActivityLine."Location Code");
        case P_ZoneType of
            P_ZoneType::BulkDecant:
                L_Zone.SetFilter(BULK, '%1', true);
            P_ZoneType::GenDecant:
                L_Zone.SetFilter(General, '%1', true);
            P_ZoneType::HighBay:
                L_Zone.SetFilter(HighBay, '%1', true);
        end;
        if not L_Zone.FindFirst() then
            exit;

        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', P_WarehouseActivityLine."Location Code");
        L_BinContent.SetFilter("Zone Code", '%1', L_Zone.Code);
        L_BinContent.SetRange("Item No.", P_WarehouseActivityLine."Item No.");
        P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
        if L_BinContent.FindFirst() then
            P_WarehouseActivityLine.Validate("Bin Code", L_BinContent."Bin Code")
        else
            P_WarehouseActivityLine."Bin Code" := '';
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
        AssignZoneBin(NewWarehouseActivityLine, 2);
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
}
