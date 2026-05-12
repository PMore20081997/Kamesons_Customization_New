codeunit 99971 "Replenishment Worksheet"
{
    procedure CreateReqWorksheet(var _ReplenishmentWorksheet: Record "Replenishment Worksheet"; L_LineNo: Integer)
    begin
        G_ReqLine.Init();
        G_ReqLine.Validate("Worksheet Template Name", _ReplenishmentWorksheet."Template Name");
        G_ReqLine.Validate("Journal Batch Name", _ReplenishmentWorksheet."Batch Name");
        G_ReqLine.Validate("Line No.", L_LineNo);
        G_ReqLine.Validate(Type, G_ReqLine.Type::Item);
        G_ReqLine.Validate("No.", _ReplenishmentWorksheet."Item No.");
        G_ReqLine.Validate("Planning Line Origin", G_ReqLine."Planning Line Origin"::"Order Planning");
        G_ReqLine.Validate("Action Message", G_ReqLine."Action Message"::New);
        G_ReqLine.Validate(Description, _ReplenishmentWorksheet.Description);
        G_ReqLine.Validate(Quantity, _ReplenishmentWorksheet."Qty to Move");
        G_ReqLine.Validate("Demand Quantity", _ReplenishmentWorksheet."Qty to Move");
        G_ReqLine.Validate("Demand Quantity (Base)", _ReplenishmentWorksheet."Qty to Move");
        G_ReqLine.Validate("Needed Quantity", _ReplenishmentWorksheet."Qty to Move");
        G_ReqLine.Validate("Needed Quantity (Base)", _ReplenishmentWorksheet."Qty to Move");
        G_ReqLine.Validate("Transfer-from Code", _ReplenishmentWorksheet."From Location Code");
        G_ReqLine.Validate("Location Code", _ReplenishmentWorksheet."Location Code");
        G_ReqLine.Validate("From Bin Code", _ReplenishmentWorksheet."From Bin Code");

        // Assign directly (not Validate) so BC does not run the "Directed Put-away and Pick" TestField.
        // OnAfterInsertTransLine copies this to Transfer Line's "Transfer-To Bin Code".
        G_ReqLine."Bin Code" := _ReplenishmentWorksheet."Bin Code";
        G_ReqLine.Validate("Replenishment System", G_ReqLine."Replenishment System"::Transfer);
        G_ReqLine.Validate("Supply From", G_KamWhseSetupLookup.GetReceiveLocation());
        G_ReqLine.Validate("Unit of Measure Code", _ReplenishmentWorksheet."Unit of Measure Code");
        G_ReqLine.Validate("Transfer Shipment Date", WorkDate());
        G_ReqLine.Validate("Due Date", WorkDate());
        G_ReqLine.Validate("Accept Action Message", true);
        G_ReqLine.Validate(Reserve, true);
        G_ReqLine.Validate("Lot No.", _ReplenishmentWorksheet."Lot No.");
        G_ReqLine.Validate("Package No.", _ReplenishmentWorksheet."Package No.");
        G_ReqLine.Validate("Lot Expiration Date", _ReplenishmentWorksheet."Expiration Date");
        G_ReqLine.Validate("Manufacturer Code", _ReplenishmentWorksheet."Manufacturer Code");
        G_ReqLine.Validate("Created By Repl.", true);
        G_ReqLine.Insert(true);
    end;

    procedure ProcessReqLineActions(var ReqLine: Record "Requisition Line")
    var
        CarryOutActionMsgReq: Report "Carry Out Action Msg. - Req.";
    begin
        CarryOutActionMsgReq.SetReqWkshLine(ReqLine);
        CarryOutActionMsgReq.UseRequestPage(false);
        CarryOutActionMsgReq.RunModal();
    end;

    var
        G_ReqLine: Record "Requisition Line";
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
}
