codeunit 99971 "Replenishment Worksheet"
{
    procedure CreateReqWorksheet(var _DecantDetails: Record "Decant Details"; L_LineNo: Integer)
    begin
        G_ReqLine.Init();
        // Journal Template Name / Batch Name are stored directly on the replenishment Decant Details record
        G_ReqLine."Worksheet Template Name" := _DecantDetails."Journal Template Name";
        G_ReqLine."Journal Batch Name" := _DecantDetails."Journal Batch Name";
        G_ReqLine.Validate("Line No.", L_LineNo);
        G_ReqLine.Validate(Type, G_ReqLine.Type::Item);
        G_ReqLine.Validate("No.", _DecantDetails."Item No.");
        G_ReqLine.Validate("Planning Line Origin", G_ReqLine."Planning Line Origin"::"Order Planning");
        G_ReqLine.Validate("Action Message", G_ReqLine."Action Message"::New);
        G_ReqLine.Validate(Description, _DecantDetails.Description);
        G_ReqLine.Validate(Quantity, _DecantDetails."To Qty.");
        G_ReqLine.Validate("Demand Quantity", _DecantDetails."To Qty.");
        G_ReqLine.Validate("Demand Quantity (Base)", _DecantDetails."To Qty.");
        G_ReqLine.Validate("Needed Quantity", _DecantDetails."To Qty.");
        G_ReqLine.Validate("Needed Quantity (Base)", _DecantDetails."To Qty.");
        // "Location Code" in Decant Details = source (receive/from) location
        G_ReqLine.Validate("Transfer-from Code", _DecantDetails."Location Code");
        // "To Location Code" in Decant Details = destination (main warehouse)
        G_ReqLine.Validate("Location Code", _DecantDetails."To Location Code");
        G_ReqLine.Validate("From Bin Code", _DecantDetails."From Bin Code");

        // Assign directly (not Validate) so BC does not run the "Directed Put-away and Pick" TestField.
        // OnAfterInsertTransLine copies this to Transfer Line's "Transfer-To Bin Code".
        G_ReqLine."Bin Code" := _DecantDetails."To Bin Code";
        G_ReqLine.Validate("Replenishment System", G_ReqLine."Replenishment System"::Transfer);
        G_ReqLine.Validate("Supply From", G_KamWhseSetupLookup.GetReceiveLocation());
        G_ReqLine.Validate("Unit of Measure Code", _DecantDetails."Unit of Measure Code");
        G_ReqLine.Validate("Transfer Shipment Date", WorkDate());
        G_ReqLine.Validate("Due Date", WorkDate());
        G_ReqLine.Validate("Accept Action Message", true);
        G_ReqLine.Validate(Reserve, true);
        G_ReqLine.Validate("Lot No.", _DecantDetails."Lot No.");
        G_ReqLine.Validate("Package No.", _DecantDetails."Package No.");
        G_ReqLine.Validate("Lot Expiration Date", _DecantDetails."Expiry Date");
        G_ReqLine.Validate("Manufacturer Code", _DecantDetails."Manufacturer Code");
        G_ReqLine."Manufacturer Name" := CopyStr(G_TaskletCodeunits.GetManufacturerName(G_ReqLine."Manufacturer Code"), 1, MaxStrLen(G_ReqLine."Manufacturer Name"));
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
        G_TaskletCodeunits: Codeunit Tasklet_Codeunits;
}
