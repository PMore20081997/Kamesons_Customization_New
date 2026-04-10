codeunit 99983 "Event Subscribers NDPP"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Put-away", OnBeforeWhseActivLineInsert, '', false, false)]
    local procedure OnBeforeWhseActivLineInsert(var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        L_Item: Record Item;
        L_Zone: Record Zone;
        L_BinContent: Record "Bin Content";
        L_AssignStockToBulk: Boolean;
        L_BulkDecntExpDate: Date;

    begin
        if WarehouseActivityLine."Location Code" <> 'BULKNDPP' then
            exit;  //Temporary++

        if (WarehouseActivityLine."Activity Type" <> WarehouseActivityLine."Activity Type"::"Put-away") OR (WarehouseActivityLine."Action Type" <> WarehouseActivityLine."Action Type"::Place) OR (WarehouseActivityLine."Source Document" <> WarehouseActivityLine."Source Document"::"Purchase Order") then
            exit;

        L_Item.SetLoadFields(BULK);
        if not L_Item.Get(WarehouseActivityLine."Item No.") then
            exit;


        // IF L_Item.BULK = true then begin
        //     if CheckAvailableQtyLessThanMinQtyinMAIN(WarehouseActivityLine) then begin
        //         if WarehouseActivityLine."Expiration Date" <= CheckEarliestExpiryInBULK(WarehouseActivityLine) then begin
        //             AssignBinZone(WarehouseActivityLine, true);
        //         end else
        //             //if (WarehouseActivityLine."Expiration Date" >= CheckEarliestExpiryInHighbay(WarehouseActivityLine)) OR (WarehouseActivityLine."Expiration Date" > CheckEarliestExpiryInBULK(WarehouseActivityLine)) then begin
        //                 AssignBinZone(WarehouseActivityLine, false);
        //         // end;
        //     end else

        //         if WarehouseActivityLine."Expiration Date" <= CheckEarliestExpiryInBULK(WarehouseActivityLine) then begin
        //             AssignBinZone(WarehouseActivityLine, true);
        //         end else
        //             AssignBinZone(WarehouseActivityLine, false);
        // end
        // else begin
        //     AssignBinZone(WarehouseActivityLine, false);
        // end;

        Clear(L_BulkDecntExpDate);
        IF L_Item.BULK = true then begin
            L_BulkDecntExpDate := CheckEarliestExpiryInBULK(WarehouseActivityLine);

            if L_BulkDecntExpDate = 0D then begin
                AssignBinZone(WarehouseActivityLine, true);
            end else if WarehouseActivityLine."Expiration Date" <= L_BulkDecntExpDate then begin
                AssignBinZone(WarehouseActivityLine, true);
            end else
                AssignBinZone(WarehouseActivityLine, false);
        end
        else begin
            AssignBinZone(WarehouseActivityLine, false);
        end;

        L_Zone.Get(WarehouseActivityLine."Location Code", WarehouseActivityLine."Zone Code");

        if L_Zone.HighBay then
            exit;

        // L_BinContent.Reset();
        // L_BinContent.SetFilter("Location Code", '%1', WarehouseActivityLine."Location Code");
        // L_BinContent.SetFilter("Zone Code", '%1', WarehouseActivityLine."Zone Code");
        // L_BinContent.SetFilter("Bin Code", '%1', WarehouseActivityLine."Bin Code");
        // L_BinContent.SetRange("Item No.", WarehouseActivityLine."Item No.");

        G_Bin.Reset();
        G_Bin.SetRange("Location Code", G_Events.GetMainWarehouse());
        G_Bin.SetRange("Zone Code", G_Events.GetPickBulkZone(G_Events.GetMainWarehouse()));
        if G_Bin.FindFirst() then;

        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', G_Events.GetMainWarehouse());
        L_BinContent.SetFilter("Zone Code", '%1', G_Events.GetPickBulkZone(G_Events.GetMainWarehouse()));
        L_BinContent.SetFilter("Bin Code", '%1', G_Bin.Code);
        L_BinContent.SetRange("Item No.", WarehouseActivityLine."Item No.");
        if L_BinContent.FindFirst() then begin
            L_BinContent.CalcFields(Quantity, "Put-away Qty.", "Pos. Adjmt. Qty.");

            Clear(G_BinContentQty);
            G_BinContentQty := L_BinContent.Quantity + L_BinContent."Put-away Qty." + L_BinContent."Pos. Adjmt. Qty.";
        end;
    end;

    // procedure CheckExpiryDateReceivedStock(var P_WhseActLine: Record "Warehouse Activity Line"): Date
    // var
    //     //L_WarehouseEntryLotDetails: Query WarehouseEntryLotDetails;
    //     L_WarehouseEntryLotDetailsLo: Query WarehouseEntryLotDetailsLoc;
    //     //L_WarehouseEntryLotDetails1: Query WarehouseEntryLotDetails;
    //     L_ReceivedStockExpDate: Date;
    //     L_MainStockExpDate: Date;
    //     L_BulkDecntStockExpDate: Date;
    //     L_HighbayStockExpDate: Date;
    //     L_SourceDoc: Enum "Warehouse Journal Source Document";
    // begin
    //     //Get Earlier Expiry BULKNDPP BULK ZONE
    //     Clear(L_ReceivedStockExpDate);
    //     L_WarehouseEntryLotDetailsLo.SetFilter(L_WarehouseEntryLotDetailsLo.Item_No_, '%1', P_WhseActLine."Item No.");
    //     L_WarehouseEntryLotDetailsLo.SetFilter(L_WarehouseEntryLotDetailsLo.Location_Code, '%1', P_WhseActLine."Location Code");
    //     L_WarehouseEntryLotDetailsLo.SetFilter(L_WarehouseEntryLotDetailsLo.Source_Document, '%1', L_SourceDoc::"P. Order");
    //     L_WarehouseEntryLotDetailsLo.SetFilter(L_WarehouseEntryLotDetailsLo.Source_No_, '%1', P_WhseActLine."Source No.");
    //     L_WarehouseEntryLotDetailsLo.SetFilter(L_WarehouseEntryLotDetailsLo.Source_Line_No_, '%1', P_WhseActLine."Source Line No.");
    //     L_WarehouseEntryLotDetailsLo.TopNumberOfRows(1);
    //     L_WarehouseEntryLotDetailsLo.Open();
    //     while L_WarehouseEntryLotDetailsLo.Read() do begin
    //         L_ReceivedStockExpDate := L_WarehouseEntryLotDetailsLo.Expiration_Date;
    //     end;
    //     L_WarehouseEntryLotDetailsLo.Close();

    //     exit(L_ReceivedStockExpDate);
    // end;

    // procedure CheckEarliestExpiryInHighbay(var P_WhseActLine: Record "Warehouse Activity Line"): Date
    // var
    //     L_WarehouseEntryLotDetails: Query WarehouseEntryLotDetails;
    //     //L_WarehouseEntryLotDetails1: Query WarehouseEntryLotDetails;
    //     L_ReceivedStockExpDate: Date;
    //     L_MainStockExpDate: Date;
    //     L_BulkDecntStockExpDate: Date;
    //     L_HighbayStockExpDate: Date;
    // begin
    //     //Get Earlier Expiry BULNDPP HIGHBAY
    //     L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Item_No_, '%1', P_WhseActLine."Item No.");
    //     L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Location_Code, '%1', 'BULKNDPP');
    //     L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Zone_Code, '%1', 'HIGHBAY');
    //     L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Quantity, '>%1', 0);
    //     L_WarehouseEntryLotDetails.TopNumberOfRows(1);
    //     L_WarehouseEntryLotDetails.Open();
    //     while L_WarehouseEntryLotDetails.Read() do begin
    //         L_HighbayStockExpDate := L_WarehouseEntryLotDetails.Expiration_Date;
    //     end;
    //     L_WarehouseEntryLotDetails.Close();

    //     exit(L_HighbayStockExpDate);
    // end;

    procedure CheckEarliestExpiryInBULK(var P_WhseActLine: Record "Warehouse Activity Line"): Date
    var
        L_WarehouseEntryLotDetails: Query WarehouseEntryLotDetails;
        //L_WarehouseEntryLotDetails1: Query WarehouseEntryLotDetails;
        L_ReceivedStockExpDate: Date;
        L_MainStockExpDate: Date;
        L_BulkDecntStockExpDate: Date;
        L_HighbayStockExpDate: Date;
    begin
        //Get Earlier Expiry BULNDPP BULK DECNT
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Item_No_, '%1', P_WhseActLine."Item No.");
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Location_Code, '%1', 'BULKNDPP');
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Zone_Code, '%1', 'BULK DECNT');
        L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Quantity, '>%1', 0);
        L_WarehouseEntryLotDetails.TopNumberOfRows(1);
        L_WarehouseEntryLotDetails.Open();
        while L_WarehouseEntryLotDetails.Read() do begin
            L_BulkDecntStockExpDate := L_WarehouseEntryLotDetails.Expiration_Date;
        end;
        L_WarehouseEntryLotDetails.Close();

        exit(L_BulkDecntStockExpDate);
    end;

    // procedure CheckEarliestExpiryInBULKMAINWarehouse(var P_WhseActLine: Record "Warehouse Activity Line"): Date
    // var
    //     L_WarehouseEntryLotDetails: Query WarehouseEntryLotDetails;
    //     //L_WarehouseEntryLotDetails1: Query WarehouseEntryLotDetails;
    //     L_ReceivedStockExpDate: Date;
    //     L_MainStockExpDate: Date;
    //     L_BulkDecntStockExpDate: Date;
    //     L_HighbayStockExpDate: Date;
    // begin
    //     // //Get Earlier Expiry MAIN PICK BULK
    //     // L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Item_No_, '%1', P_WhseActLine."Item No.");
    //     // L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Location_Code, '%1', 'MAIN');
    //     // L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Zone_Code, '%1', 'PICK BULK');
    //     // L_WarehouseEntryLotDetails.SetFilter(L_WarehouseEntryLotDetails.Quantity, '>%1', 0);
    //     // L_WarehouseEntryLotDetails.TopNumberOfRows(1);
    //     // L_WarehouseEntryLotDetails.Open();
    //     // while L_WarehouseEntryLotDetails.Read() do begin
    //     //     L_MainStockExpDate := L_WarehouseEntryLotDetails.Expiration_Date;
    //     // end;
    //     // L_WarehouseEntryLotDetails.Close();

    //     //exit(L_MainStockExpDate);
    // end;

    procedure CheckAvailableQtyLessThanMinQtyinMAIN(VP_WhseActLine: Record "Warehouse Activity Line"): Boolean
    var
        L_MainBinContent: Record "Bin Content";
        L_MainQtyAvailToTake: Decimal;
    begin
        Clear(L_MainQtyAvailToTake);
        L_MainBinContent.Reset();
        L_MainBinContent.SetRange("Item No.", VP_WhseActLine."Item No.");
        L_MainBinContent.SetFilter("Location Code", '%1', 'MAIN');
        L_MainBinContent.SetFilter("Bin Code", '%1', 'PICK BULK');
        L_MainBinContent.SetFilter(Quantity, '>%1', 0);
        if L_MainBinContent.FindFirst() then begin

            // if L_MainBinContent."Min. Qty." = 0 then
            //     exit;

            L_MainQtyAvailToTake := L_MainBinContent.CalcQtyAvailToTake(0);
        end;

        if L_MainQtyAvailToTake < L_MainBinContent."Min. Qty." then
            exit(true)
        else
            exit(false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterInsertEvent, '', false, false)]
    local procedure OnAfterInsertEventWAL(var Rec: Record "Warehouse Activity Line")
    var
        L_BinContent: Record "Bin Content";
        L_WhseActivLine: Record "Warehouse Activity Line";
        L_Zone: Record Zone;
    // L_Events: Codeunit Events;

    // L_Bin: Record Bin;
    begin
        if Rec."Location Code" <> 'BULKNDPP' then
            exit; //Temporary++

        If L_Zone.Get(Rec."Location Code", Rec."Zone Code") then;


        // if (not G_IsExecuting) OR (L_Zone.HighBay) then
        //     exit;

        if (Rec."Activity Type" <> Rec."Activity Type"::"Put-away") OR (Rec."Action Type" <> Rec."Action Type"::Place) OR (Rec."Source Document" <> Rec."Source Document"::"Purchase Order") OR (not G_IsExecuting) OR (L_Zone.HighBay) then
            exit;

        // L_BinContent.Reset();
        // L_BinContent.SetFilter("Location Code", '%1', Rec."Location Code");
        // L_BinContent.SetFilter("Zone Code", '%1', Rec."Zone Code");
        // L_BinContent.SetFilter("Bin Code", '%1', Rec."Bin Code");
        // L_BinContent.SetRange("Item No.", Rec."Item No.");

        G_Bin.Reset();
        G_Bin.SetRange("Location Code", G_Events.GetMainWarehouse());
        G_Bin.SetRange("Zone Code", G_Events.GetPickBulkZone(G_Events.GetMainWarehouse()));
        if G_Bin.FindFirst() then;

        L_BinContent.Reset();
        L_BinContent.SetFilter("Location Code", '%1', G_Events.GetMainWarehouse());
        L_BinContent.SetFilter("Zone Code", '%1', G_Events.GetPickBulkZone(G_Events.GetMainWarehouse()));
        L_BinContent.SetFilter("Bin Code", '%1', G_Bin.Code);
        L_BinContent.SetRange("Item No.", Rec."Item No.");
        if L_BinContent.FindFirst() then begin
            //L_BinContent.CalcFields(Quantity, "Put-away Qty.", "Pos. Adjmt. Qty.");

            if (L_BinContent."Max. Qty." > 0) AND ((G_BinContentQty + Rec.Quantity) > L_BinContent."Max. Qty.") then begin

                //Clear(G_RemainingQty);
                Clear(G_SplitQtyToHandle);


                // if L_BinContent."Max. Qty." <> 0 then begin
                //     G_RemainingQty := Max(L_BinContent."Max. Qty." * L_BinContent."Qty. per Unit of Measure" - G_BinContentQty, 0);
                // END;

                // G_SplitQtyToHandle := Rec.Quantity - G_RemainingQty;
                //G_SplitQtyToHandle := (G_BinContentQty + Rec.Quantity) - L_BinContent."Max. Qty.";
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

                    AssignBinZone(Rec, false);
                    Rec.Modify();
                end;
            end;
        end;

        Clear(G_BinContentQty); //Test++
    end;

    local procedure AssignBinZone(var P_WarehouseActivityLine: Record "Warehouse Activity Line"; IsBulk: Boolean)
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

            // P_WarehouseActivityLine."Zone Code" := L_Zone.Code;
            // P_WarehouseActivityLine."Bin Code" := L_BinContent."Bin Code";
        end else begin
            //Temporary++
            L_BinContent.Reset();
            L_BinContent.SetFilter("Location Code", '%1', P_WarehouseActivityLine."Location Code");
            L_BinContent.SetFilter("Zone Code", '%1', L_Zone.Code);
            L_BinContent.SetRange("Item No.", P_WarehouseActivityLine."Item No.");
            L_BinContent.SetFilter(Fixed, '%1', true);
            if L_BinContent.FindFirst() then begin
                // P_WarehouseActivityLine."Zone Code" := L_BinContent."Zone Code";
                // P_WarehouseActivityLine."Bin Code" := L_BinContent."Bin Code";
                P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
                P_WarehouseActivityLine.Validate("Bin Code", L_BinContent."Bin Code");
                //Temporary--
            end else
                P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
        end;
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
        AssignBinZone(NewWarehouseActivityLine, false);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnSplitLineOnBeforeRenumberAllLines, '', false, false)]
    local procedure OnSplitLineOnBeforeRenumberAllLines(var LineSpacing: Integer)
    begin
        if G_LineSpacing then
            LineSpacing := 5000;
    end;

    local procedure "Max"(Value1: Decimal; Value2: Decimal): Decimal
    begin
        if Value1 >= Value2 then
            exit(Value1);
        exit(Value2);
    end;

    var
        G_RemainingQty: Decimal;
        G_SplitQtyToHandle: Decimal;
        G_IsExecuting: Boolean;
        G_LineSpacing: Boolean;
        G_BinContentQty: Decimal;
        //G_QtyToPutAway: Decimal;
        G_Events: Codeunit Events;
        G_Bin: Record Bin;
}
