namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Customer;

// -------------------------------------------------------------------------------------
// Goods Out Screen on Tasklet Mobile WMS — "Unplanned / Adhoc Registration" pattern.
//
//   Registration type "GoodsOut" — same shape as the Collection screen:
//     Header   ToteNo      -> operator scans / enters the Tote No. (visible header
//                             field; scanning it accepts the header).
//     Step 20  CustomerNo  -> operator picks a Customer from the
//                             "GoodsOutCustomers" data table (Code = No., Name = Name).
//
//   The device only requests the steps after the header is accepted, and it
//   cannot accept a header whose fields are all hidden — so Tote No. lives in
//   the header rather than as a step.
//
//   The header configuration and the data table are sent to the device as
//   reference data (on login / refresh), so changes appear after the device
//   reloads reference data.
//
//   Device side: menu item + page "GoodsOutScreen" in application.cfg, with
//   <header configurationKey="GoodsOutHeader" automaticAcceptAfterLastScan="true"/>.
//
// On post (green tick) a KNAPP Goods Out Order is created and sent for the tote
// and customer - Cod99977 "KNAPP BULK Goods Out Mgt.".SendToteGoodsOutOrder.
// -------------------------------------------------------------------------------------

codeunit 99978 "Goods Out Screen Tasklet"
{
    Access = Public;

    var
        GoodsOutRegTypeTok: Label 'GoodsOut', Locked = true;
        GoodsOutHeaderTok: Label 'GoodsOutHeader', Locked = true;
        CustomersDataTableTok: Label 'GoodsOutCustomers', Locked = true;
        ToteNoFieldNameTok: Label 'ToteNo', Locked = true;
        CustomerNoStepNameTok: Label 'CustomerNo', Locked = true;
        MissingToteNoErr: Label 'Tote No. must be scanned.';
        MissingCustomerErr: Label 'A Customer must be selected.';
        PostSuccessMsg: Label 'Goods Out Order %1 sent to KNAPP for tote %2, customer %3.', Comment = '%1 = Goods Out No., %2 = Tote No., %3 = Customer No.';

    // ---------- 0. Header configuration -------------------------------------

    // Tote No. is the (only) header field. Scanning it accepts the header
    // (automaticAcceptAfterLastScan), which makes the device request the steps.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Reference Data", 'OnGetReferenceData_OnAddHeaderConfigurations', '', true, true)]
    local procedure OnAddHeaderConfigurations_GoodsOut(var _HeaderFields: Record "MOB HeaderField Element")
    begin
        _HeaderFields.InitConfigurationKey(GoodsOutHeaderTok);

        _HeaderFields.Create_TextField(1, ToteNoFieldNameTok, 'Scan Tote No.:');
        _HeaderFields.Set_optional(false);
        _HeaderFields.Set_acceptBarcode(true);
        _HeaderFields.Set_clearOnClear(true);
    end;

    // ---------- 1. Reference data: Customers list -----------------------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Reference Data", 'OnGetReferenceData_OnAddDataTables', '', true, true)]
    local procedure OnAddDataTables_GoodsOutCustomers(var _DataTable: Record "MOB DataTable Element"; _MobileUserID: Code[50])
    var
        Customer: Record Customer;
    begin
        _DataTable.InitDataTable(CustomersDataTableTok);

        Customer.SetRange(Blocked, Customer.Blocked::" ");
        if Customer.FindSet() then
            repeat
                _DataTable.Create_CodeAndName(Customer."No.", Customer.Name);
            until Customer.Next() = 0;
    end;

    // ---------- 2. Registration steps: Customer ------------------------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnGetRegistrationConfiguration_OnAddSteps', '', true, true)]
    local procedure OnAddSteps_GoodsOut(_RegistrationType: Text; var _HeaderFieldValues: Record "MOB NS Request Element"; var _Steps: Record "MOB Steps Element"; var _RegistrationTypeTracking: Text)
    begin
        if _RegistrationType <> GoodsOutRegTypeTok then
            exit;

        _Steps.Create_ListStepFromDataTable(20, CustomerNoStepNameTok, 'Select Customer', 'Customer:', 'Select the customer', CustomersDataTableTok, 'Code', 'Name', '');
    end;

    // ---------- 3. Posting ---------------------------------------------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistrationOnCustomRegistrationType', '', true, true)]
    local procedure OnPostAdhocRegistration_GoodsOut(_MessageId: Guid; _RegistrationType: Text; var _RequestValues: Record "MOB NS Request Element"; var _CurrentRegistrations: Record "MOB WMS Registration"; var _Commands: Record "MOB Command Element"; var _SuccessMessage: Text; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        ToteNo: Code[50];
        CustomerNo: Code[20];
        GoodsOutNo: Code[20];
    begin
        if _IsHandled then
            exit;
        if _RegistrationType <> GoodsOutRegTypeTok then
            exit;

        // Tote No. is a header value, which can arrive in the request context
        // rather than as a plain value — read it with GetValueOrContextValue.
        ToteNo := CopyStr(_RequestValues.GetValueOrContextValue(ToteNoFieldNameTok), 1, MaxStrLen(ToteNo));
        CustomerNo := CopyStr(_RequestValues.GetValue(CustomerNoStepNameTok), 1, MaxStrLen(CustomerNo));

        if ToteNo = '' then
            Error(MissingToteNoErr);
        if CustomerNo = '' then
            Error(MissingCustomerErr);

        GoodsOutNo := PostGoodsOut(ToteNo, CustomerNo);

        _SuccessMessage := StrSubstNo(PostSuccessMsg, GoodsOutNo, ToteNo, CustomerNo);
        _RegistrationTypeTracking := StrSubstNo('%1|%2|%3', GoodsOutNo, ToteNo, CustomerNo);
        _IsHandled := true;
    end;

    // Builds and sends the KNAPP Goods Out Order (GO Order with shipping label and
    // STRAPPING) for the tote - see Cod99977 SendToteGoodsOutOrder.
    local procedure PostGoodsOut(ToteNo: Code[50]; CustomerNo: Code[20]): Code[20]
    var
        KnappBulkGoodsOutMgt: Codeunit "KNAPP BULK Goods Out Mgt.";
    begin
        exit(KnappBulkGoodsOutMgt.SendToteGoodsOutOrder(ToteNo, CustomerNo));
    end;
}
