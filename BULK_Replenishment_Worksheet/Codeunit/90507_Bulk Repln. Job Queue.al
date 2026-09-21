codeunit 99972 "Bulk Repln. Job Queue"
{
    // Designed to be registered in Job Queue as Object Type = Codeunit, Object ID = 90507.
    // Automates: Calculate Bin Replenishment → Register (equivalent to pressing both buttons
    // on the Bulk Replan page unattended).
    //
    // Flow:
    //   1. Clear stale Replenishment-type Decant Details lines for the batch.
    //   2. Run Cal _Bin Replenishment New (same as Calculate button) — the report
    //      inserts straight into Decant Details.
    //   3. Run Register logic: create Requisition Lines, carry out action messages.

    trigger OnRun()
    begin
        RunBulkReplenishment();
    end;

    local procedure RunBulkReplenishment()
    var
        L_DecantDetails: Record "Decant Details";
        L_ReqLine: Record "Requisition Line";
        L_ReplenishmentWksh: Codeunit "Replenishment Worksheet";
        ReplenishBinContent: Report "Cal _Bin Replenishment New";
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        L_TemplateName: Code[10];
        L_BatchName: Code[10];
        L_ReqLineNo: Integer;
    begin
        GetJournalTemplateBatch(L_TemplateName, L_BatchName);

        // Clear previous unprocessed Replenishment-type Decant Details so the report starts fresh
        L_DecantDetails.Reset();
        L_DecantDetails.SetRange("Entry Type", L_DecantDetails."Entry Type"::Replenishment);
        L_DecantDetails.SetRange("Journal Template Name", L_TemplateName);
        L_DecantDetails.SetRange("Journal Batch Name", L_BatchName);
        if not L_DecantDetails.IsEmpty() then
            L_DecantDetails.DeleteAll();

        // Step 1 – Calculate Bin Replenishment (mirrors the Calculate button).
        // The report inserts Accept lines straight into Decant Details.
        Commit();
        ReplenishBinContent.InitializeRequest(L_TemplateName, L_BatchName, L_KamWhseSetupLookup.GetMainLocation(), false);
        ReplenishBinContent.UseRequestPage(false);
        ReplenishBinContent.Run();
        Clear(ReplenishBinContent);
        Commit();

        // Step 2 – Register (mirrors the Register button)
        L_DecantDetails.Reset();
        L_DecantDetails.SetRange("Entry Type", L_DecantDetails."Entry Type"::Replenishment);
        L_DecantDetails.SetRange("Status", L_DecantDetails."Status"::Accept);
        L_DecantDetails.SetRange("Journal Template Name", L_TemplateName);
        L_DecantDetails.SetRange("Journal Batch Name", L_BatchName);
        L_DecantDetails.SetFilter("To Qty.", '>%1', 0);
        if not L_DecantDetails.FindSet() then
            exit;

        L_ReqLine.Reset();
        L_ReqLine.SetRange("Journal Batch Name", L_BatchName);
        L_ReqLine.SetRange("Created By Repl.", true);
        if not L_ReqLine.IsEmpty() then
            L_ReqLine.DeleteAll();

        repeat
            L_ReqLineNo += 10000;
            L_ReplenishmentWksh.CreateReqWorksheet(L_DecantDetails, L_ReqLineNo);
        until L_DecantDetails.Next() = 0;

        L_DecantDetails.DeleteAll();

        L_ReqLine.Reset();
        L_ReqLine.SetRange("Journal Batch Name", L_BatchName);
        L_ReqLine.SetRange("Created By Repl.", true);
        if L_ReqLine.FindSet() then
            L_ReplenishmentWksh.ProcessReqLineActions(L_ReqLine);
    end;

    local procedure GetJournalTemplateBatch(var TemplateName: Code[10]; var BatchName: Code[10])
    var
        WhseJnlTemplate: Record "Warehouse Journal Template";
        WhseJnlBatch: Record "Warehouse Journal Batch";
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        L_ReceiveLocation: Code[20];
        TemplateNotFoundErr: Label 'No Warehouse Journal Template found for the Bulk Replan page (ID %1). Open the page once to initialise the template.', Comment = '%1 = Page ID';
        BatchNotFoundErr: Label 'No Warehouse Journal Batch found for template %1.', Comment = '%1 = Template Name';
    begin
        // The Bulk Replan page registers its template with "Page ID" = PAGE::"Bulk Replan"
        WhseJnlTemplate.Reset();
        WhseJnlTemplate.SetRange("Page ID", Page::"Bulk Replan");
        if not WhseJnlTemplate.FindFirst() then
            if not WhseJnlTemplate.Get('REPLENISH') then
                Error(TemplateNotFoundErr, Page::"Bulk Replan");
        TemplateName := WhseJnlTemplate.Name;

        // Prefer the batch that belongs to the Receive location; fall back to any batch
        L_ReceiveLocation := L_KamWhseSetupLookup.GetReceiveLocation();
        WhseJnlBatch.Reset();
        WhseJnlBatch.SetRange("Journal Template Name", TemplateName);
        WhseJnlBatch.SetRange("Location Code", CopyStr(L_ReceiveLocation, 1, 10));
        if not WhseJnlBatch.FindFirst() then begin
            WhseJnlBatch.SetRange("Location Code");
            if not WhseJnlBatch.FindFirst() then
                Error(BatchNotFoundErr, TemplateName);
        end;
        BatchName := WhseJnlBatch.Name;
    end;
}
