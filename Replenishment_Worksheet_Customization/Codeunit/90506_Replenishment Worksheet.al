codeunit 99971 "Replenishment Worksheet"
{
    SingleInstance = true;
    trigger OnRun()
    begin

    end;



    local procedure GetPickBulkBin()
    var
        myInt: Integer;
    begin

    end;

    procedure CreateTransferOrder(Var _ReplenishmentWorksheet: Record "Replenishment Worksheet"; _ToZoneCode: Code[20]): Boolean
    var
        L_TransferHeader: Record "Transfer Header";
        L_TransferLine: Record "Transfer Line";
        LastTransferLine: Record "Transfer Line";
        HeaderCreated: Boolean;
        L_ReplenishmentReport: Report "Cal _Bin Replenishment New";
    begin
        //Clear and Reset Variables++
        Clear(HeaderCreated);
        Clear(NextLineNo);
        Clear(G_ToZoneCode);
        NextLineNo := 10000;
        G_ToZoneCode := _ToZoneCode;


        //Create Temp Record++++
        _ReplenishmentWorksheet.SetCurrentKey("From Location Code");
        _ReplenishmentWorksheet.Ascending(true);
        if _ReplenishmentWorksheet.FindSet() then begin
            repeat
                _ReplenishmentWorksheet.TestField("From Location Code");
                _ReplenishmentWorksheet.TestField("Qty to Move");

            until _ReplenishmentWorksheet.Next() = 0;

            //Create Transfer Order from Temp Table+++
            exit(CreateTransferOrderFromTempTable())
        end;
    end;

    procedure CreateTransferOrderFromTempTable() _HeaderCreated: Boolean
    var
        L_TransferHeader: Record "Transfer Header";
        L_TransferLine: Record "Transfer Line";
        LastTransferLine: Record "Transfer Line";
        LocationCodeLoop: Code[20];
        TempReplenishmentWorksheet_ForLoop: Record "Replenishment Worksheet" temporary; //Dont remove Temp property++
        L_ItemNoLoop: Code[20];
        L_LineNo: Integer;
    begin
        #region Set record for loop process+++
        TempReplenishmentWorksheet_ForLoop.Reset();
        TempReplenishmentWorksheet_ForLoop.DeleteAll();
        Temp_TempReplenishmentWorksheet.Reset();
        if Temp_TempReplenishmentWorksheet.FindSet() then begin
            repeat
                TempReplenishmentWorksheet_ForLoop.Init();
                TempReplenishmentWorksheet_ForLoop.TransferFields(Temp_TempReplenishmentWorksheet);
                TempReplenishmentWorksheet_ForLoop.Insert();
            until Temp_TempReplenishmentWorksheet.Next() = 0;
        end;
        #Endregion Set record for loop process+++

        //Clear Variable++
        Clear(L_LineNo);
        Clear(LocationCodeLoop);
        Clear(_HeaderCreated);

        //Get Total Break Count++


        #region Process to Create Transfer Order++++++++
        Temp_TempReplenishmentWorksheet.Reset();
        Temp_TempReplenishmentWorksheet.SetCurrentKey("From Location Code");
        Temp_TempReplenishmentWorksheet.Ascending(true);
        if Temp_TempReplenishmentWorksheet.FindSet() then begin
            repeat
                if LocationCodeLoop <> Temp_TempReplenishmentWorksheet."From Location Code" then begin

                    //Clear(Counter);
                    TempReplenishmentWorksheet_ForLoop.Reset();
                    TempReplenishmentWorksheet_ForLoop.SetRange("From Location Code", Temp_TempReplenishmentWorksheet."From Location Code");
                    TempReplenishmentWorksheet_ForLoop.SetRange("System-Created Entry", false);
                    TempReplenishmentWorksheet_ForLoop.SetCurrentKey("Item No.");
                    TempReplenishmentWorksheet_ForLoop.Ascending(true);
                    if TempReplenishmentWorksheet_ForLoop.FindSet() then begin
                        Clear(L_LineNo);

                        //Create Header+++
                        InsertedTH.Reset();
                        if CreateTransferHeaderFromTemporary(TempReplenishmentWorksheet_ForLoop) = true then
                            _HeaderCreated := true
                        else
                            Error('The transfer header does not exist.');
                        repeat
                            //Get Line No +++
                            L_LineNo := L_LineNo + 10000;

                            //Create Line++
                            CreateTransferLineFromTemporary(G_SNo, TempReplenishmentWorksheet_ForLoop, L_LineNo);

                            //Update System Create Entry for next loop+++
                            TempReplenishmentWorksheet_ForLoop."System-Created Entry" := true;
                            TempReplenishmentWorksheet_ForLoop.Modify();

                        until TempReplenishmentWorksheet_ForLoop.Next() = 0;
                    end;
                end;

                //++++
                LocationCodeLoop := Temp_TempReplenishmentWorksheet."From Location Code";
            until Temp_TempReplenishmentWorksheet.Next() = 0;
        end;
        #Endregion Process to Create Transfer Order++++++++
    end;


    local procedure CreateTransferHeaderFromTemporary(_Temporary_ReplenishmentWorksheet: Record "Replenishment Worksheet" temporary): Boolean
    var
        NoSeries: Codeunit "No. Series";
        L_InventorySetup: Record "Inventory Setup";
    begin
        L_InventorySetup.Get();
        Clear(G_SNo);
        InsertedTH.Reset();
        InsertedTH.Init();
        InsertedTH."No." := NoSeries.PeekNextNo(L_InventorySetup."Transfer Order Nos.", WorkDate());
        NoSeries.GetNextNo(L_InventorySetup."Transfer Order Nos.", WorkDate());
        InsertedTH.Validate("Transfer-from Code", Temp_TempReplenishmentWorksheet."From Location Code");
        InsertedTH.Validate("Transfer-to Code", Temp_TempReplenishmentWorksheet."Location Code");
        InsertedTH.Validate("Posting Date", Temp_TempReplenishmentWorksheet."Posting Date");
        InsertedTH.Validate("Shipment Date", Temp_TempReplenishmentWorksheet."Posting Date");
        InsertedTH.Validate("Receipt Date", Temp_TempReplenishmentWorksheet."Posting Date");
        InsertedTH.Validate("Replenishment Batch Name", Temp_TempReplenishmentWorksheet."Batch Name");
        InsertedTH.Validate("Transfer-To Zone Code", G_ToZoneCode);

        if InsertedTH.Insert(true) = true then begin
            InsertedTH.Validate("Direct Transfer", true);
            G_SNo := InsertedTH."No.";
            exit(true);
        end else
            exit(false);
    end;

    local procedure CreateTransferLineFromTemporary(_SalesOrderNo: Code[20]; _Temporary_ReplenishmentWorksheet: Record "Replenishment Worksheet" temporary; _LineNumber: Integer)
    var
        L_TransferHeader: Record "Transfer Header";
        L_TransferLine: Record "Transfer Line";
        TempReservationEntry1: Record "Reservation Entry";
        L_CreateReservEntry: Codeunit "Create Reserv. Entry";
        L_ResStatus: Enum "Reservation Status";
    begin
        L_TransferHeader.Reset();
        L_TransferHeader.SetRange("No.", _SalesOrderNo);
        if L_TransferHeader.FindFirst() then begin
            L_TransferLine.Init();
            L_TransferLine.Validate("Document No.", L_TransferHeader."No.");
            L_TransferLine."Line No." := _LineNumber;
            L_TransferLine.Validate("Item No.", _Temporary_ReplenishmentWorksheet."Item No.");
            L_TransferLine.Validate("Variant Code", _Temporary_ReplenishmentWorksheet."Variant Code");
            L_TransferLine.Validate("Transfer-from Code", _Temporary_ReplenishmentWorksheet."From Location Code");
            L_TransferLine.Validate("Transfer-from Bin Code", _Temporary_ReplenishmentWorksheet."From Bin Code");
            L_TransferLine.Validate("Transfer-to Code", _Temporary_ReplenishmentWorksheet."Location Code");
            L_TransferLine."Transfer-To Bin Code" := '';
            L_TransferLine.Validate(Quantity, _Temporary_ReplenishmentWorksheet."Qty to Move");
            L_TransferLine.Insert();

        end;
    end;


    #region New  Code for Transfer Order++
    procedure CreateReqWorksheet(var _ReplenishmentWorksheet: Record "Replenishment Worksheet"; L_LineNo: Integer)
    var
    //L_ReplenishmentWorksheet: Record "Replenishment Worksheet";
    //L_ReplenishmentWorksheetCode: Codeunit "Replenishment Worksheet";

    //New++
    //TempReplenishmentWorksheet_ForLoop: Record "Replenishment Worksheet" temporary;


    //L_CarryOutActionMsg: Codeunit "Carry Out Action";

    //LocationCodeLoop: Code[20];
    begin

        // _ReplenishmentWorksheet.MarkedOnly(true);


        //Clear(LocationCodeLoop);
        // TempReplenishmentWorksheet_ForLoop.Reset();
        // TempReplenishmentWorksheet_ForLoop.DeleteAll();
        // //_ReplenishmentWorksheet.Reset();

        // _ReplenishmentWorksheet.SetCurrentKey("From Location Code");
        // _ReplenishmentWorksheet.Ascending(true);
        // if _ReplenishmentWorksheet.FindSet() then begin
        //     repeat
        //         TempReplenishmentWorksheet_ForLoop.Init();
        //         TempReplenishmentWorksheet_ForLoop.TransferFields(_ReplenishmentWorksheet);
        //         TempReplenishmentWorksheet_ForLoop.Insert();
        //     until _ReplenishmentWorksheet.Next() = 0;
        // end;


        // if _ReplenishmentWorksheet.FindSet() then begin
        //     repeat
        // TempReplenishmentWorksheet_ForLoop.Reset();
        // TempReplenishmentWorksheet_ForLoop.SetRange("From Location Code", _ReplenishmentWorksheet."From Location Code");
        // TempReplenishmentWorksheet_ForLoop.SetRange("System-Created Entry", false);
        // TempReplenishmentWorksheet_ForLoop.SetCurrentKey("Item No.");
        // TempReplenishmentWorksheet_ForLoop.Ascending(true);
        // if TempReplenishmentWorksheet_ForLoop.FindSet() then begin
        //     repeat
        //L_LineNo := L_LineNo + 10000;

        G_TempReqLine.Init();
        G_TempReqLine.Validate("Worksheet Template Name", _ReplenishmentWorksheet."Template Name");
        G_TempReqLine.Validate("Journal Batch Name", _ReplenishmentWorksheet."Batch Name");
        G_TempReqLine.Validate("Line No.", L_LineNo);
        G_TempReqLine.Validate(Type, G_TempReqLine.Type::Item);
        G_TempReqLine.Validate("No.", _ReplenishmentWorksheet."Item No.");
        G_TempReqLine.Validate("Planning Line Origin", G_TempReqLine."Planning Line Origin"::"Order Planning");
        G_TempReqLine.Validate("Action Message", G_TempReqLine."Action Message"::New);
        G_TempReqLine.Validate(Description, _ReplenishmentWorksheet.Description);
        G_TempReqLine.Validate(Quantity, _ReplenishmentWorksheet."Qty to Move");
        G_TempReqLine.Validate("Demand Quantity", _ReplenishmentWorksheet."Qty to Move");
        G_TempReqLine.Validate("Demand Quantity (Base)", _ReplenishmentWorksheet."Qty to Move");
        G_TempReqLine.Validate("Needed Quantity", _ReplenishmentWorksheet."Qty to Move");
        G_TempReqLine.Validate("Needed Quantity (Base)", _ReplenishmentWorksheet."Qty to Move");
        G_TempReqLine.Validate("Transfer-from Code", _ReplenishmentWorksheet."From Location Code");
        G_TempReqLine.Validate("Location Code", _ReplenishmentWorksheet."Location Code");
        G_TempReqLine.Validate("From Bin Code", _ReplenishmentWorksheet."From Bin Code");
        G_TempReqLine.Validate("Bin Code", 'PICK BULK');
        G_TempReqLine.Validate("Replenishment System", G_TempReqLine."Replenishment System"::Transfer);
        G_TempReqLine.Validate("Supply From", 'BULKNDPP');
        G_TempReqLine.Validate("Unit of Measure Code", _ReplenishmentWorksheet."Unit of Measure Code");
        G_TempReqLine.Validate("Transfer Shipment Date", WorkDate());
        G_TempReqLine.Validate("Due Date", WorkDate());
        G_TempReqLine.Validate("Accept Action Message", true);
        G_TempReqLine.Validate(Reserve, true);
        G_TempReqLine.Validate("Lot No.", _ReplenishmentWorksheet."Lot No.");
        G_TempReqLine.Validate("Package No.", _ReplenishmentWorksheet."Package No.");
        G_TempReqLine.Validate("Lot Expiration Date", _ReplenishmentWorksheet."Expiration Date");
        G_TempReqLine.Validate("Created By Repl.", true);
        G_TempReqLine.Insert(true);

        // _ReplenishmentWorksheet."System-Created Entry" := true;
        // _ReplenishmentWorksheet.Modify();

        //     until TempReplenishmentWorksheet_ForLoop.Next() = 0;
        // end;
        //     until _ReplenishmentWorksheet.Next() = 0;
        // end;

        // _ReplenishmentWorksheet.MarkedOnly(false);

        //ProcessReqLineActions(G_TempReqLine);

        //Final Message++
    end;

    procedure ProcessReqLineActions(var ReqLine: Record "Requisition Line")
    var
        CarryOutActionMsgReq: Report "Carry Out Action Msg. - Req.";
    begin
        CarryOutActionMsgReq.SetReqWkshLine(ReqLine);
        CarryOutActionMsgReq.UseRequestPage(false);
        CarryOutActionMsgReq.RunModal();
    end;
    #Endregion New Code for Transfer Order--

    var
        NextLineNo: Integer;
        G_ToZoneCode: Code[20];
        //TempReplenishmentWorksheet: Record "Replenishment Worksheet" temporary; //Dont remove Temp property++
        Temp_TempReplenishmentWorksheet: Record "Replenishment Worksheet"; //Temporary++
        InsertedTH: Record "Transfer Header";
        G_SNo: Code[20];

        //New++
        G_TempReqLine: Record "Requisition Line";



}