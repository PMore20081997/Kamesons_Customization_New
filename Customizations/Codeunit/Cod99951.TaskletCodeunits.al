namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Journal;
using Microsoft.Inventory.Journal;

codeunit 99951 Tasklet_Codeunits
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Setup Doc. Types", 'OnAfterCreateDefaultDocumentTypes', '', true, true)]
    local procedure RegisterLineSelectionDocumentType()
    var
        MobWmsSetupDocTypes: Codeunit "MOB WMS Setup Doc. Types";
    begin
        MobWmsSetupDocTypes.CreateDocumentType('GetReceiveLineInformation', '', Codeunit::"MOB WMS Whse. Inquiry");
        MobWmsSetupDocTypes.CreateDocumentType('ValidateManufactureCode', '', Codeunit::"MOB WMS Whse. Inquiry");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Whse. Inquiry", 'OnWhseInquiryOnCustomDocumentType', '', true, true)]
    local procedure OnWhseInquiry_GetReceiveLineInformation(_DocumentType: Text; var _RequestValues: Record "MOB NS Request Element"; var _ResponseElement: Record "MOB NS Resp Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        L_ScannedValue: Text;
        L_ItemNo: Code[20];
    begin
        if _IsHandled then
            exit;
        if not _DocumentType.Contains('GetReceiveLineInformation') then
            exit;

        Clear(G_ScannedBarcode);
        Clear(G_MfrCode);


        L_ScannedValue := _RequestValues.GetValue('ScannedValue', false);
        if L_ScannedValue = '' then
            L_ScannedValue := _RequestValues.GetValue('SerialNumber', false);
        if L_ScannedValue = '' then
            L_ScannedValue := _RequestValues.GetValue('ItemNumber', false);

        G_ScannedBarcode := CopyStr(L_ScannedValue, 1, MaxStrLen(G_ScannedBarcode));

        L_ItemNo := GetItemNoFromBarcode(G_ScannedBarcode);
        if L_ItemNo = '' then
            exit;

        G_MfrCode := GetManufacturerFromBarcode(L_ItemNo, G_ScannedBarcode);

        // Manufacturer validity is enforced by the Manufacture Code step's online
        // validation (ValidateManufactureCode).

        _ResponseElement.Create('select');
        _ResponseElement.SetValue('@name', 'ItemNumber');
        _ResponseElement.SetValue('@value', L_ItemNo);
        if G_MfrCode <> '' then begin
            _ResponseElement.SetValue('values', '');
            _ResponseElement.SetValue('/values/ManufactureCode', G_MfrCode);
            _ResponseElement.SetValue('/values/ItemNo', L_ItemNo);
        end;

        _IsHandled := true;
    end;

    // Online validation for the Manufacture Code step. Fires when the operator
    // confirms the step value. Rejects the value with an Error (shown on the
    // device) if the entered Manufacturer is not set up for the line's Item No.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Whse. Inquiry", 'OnWhseInquiryOnCustomDocumentType', '', true, true)]
    local procedure OnWhseInquiry_ValidateManufactureCode(_DocumentType: Text; var _RequestValues: Record "MOB NS Request Element"; var _ResponseElement: Record "MOB NS Resp Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        L_ItemNo: Code[20];
        L_MfrCode: Code[100];
    begin
        if _IsHandled then
            exit;
        if _DocumentType <> 'ValidateManufactureCode' then
            exit;

        L_MfrCode := CopyStr(_RequestValues.GetValue('ManufactureCode', false), 1, MaxStrLen(L_MfrCode));

        // Item No. comes from the hidden 'ItemNo' step, sent here via
        // includeCollectedValues=true on the Manufacture Code step's online validation.
        L_ItemNo := CopyStr(_RequestValues.GetValue('ItemNo', false), 1, MaxStrLen(L_ItemNo));

        if not ManufacturerExistsInTable(L_ItemNo, L_MfrCode) then
            Error(ManufacturerNotInTableErr, L_MfrCode, L_ItemNo);

        _IsHandled := true;
    end;

    // Resolve the Item No. from the scanned Bar Code Item Reference.
    local procedure GetItemNoFromBarcode(_Barcode: Code[50]): Code[20]
    var
        L_ItemRef: Record "Item Reference";
    begin
        if _Barcode = '' then
            exit('');
        L_ItemRef.SetRange("Reference Type", L_ItemRef."Reference Type"::"Bar Code");
        L_ItemRef.SetRange("Reference No.", _Barcode);
        if L_ItemRef.FindFirst() then
            exit(L_ItemRef."Item No.");
        exit('');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Receive", 'OnGetReceiveOrderLines_OnAddStepsToAnyLine', '', true, true)]
    local procedure My02OnGetReceiveOrderLines_OnAddManufactureCodeStep(_RecRef: RecordRef; var _BaseOrderLineElement: Record "MOB NS BaseDataModel Element"; var _Steps: Record "MOB Steps Element")
    var
        L_ItemNo: Code[20];
        L_ListValues: Text;
        L_DefaultValue: Text;
    begin
        // This event fires at line-load time, BEFORE the operator scans, so the
        // SingleInstance G_MfrCode is blank here — do not rely on it. The list
        // (built from the Item Manufacturer Table plus the item's Bar Code Item
        // Reference manufacturers) already contains the scannable codes; the
        // scanned value is pre-selected later via the line-selection <select>
        // response (/values/ManufactureCode).
        L_ItemNo := CopyStr(_BaseOrderLineElement.Get_ItemNumber(), 1, MaxStrLen(L_ItemNo));
        L_ListValues := BuildManufacturerCodeListValues(L_ItemNo);

        // Hidden step carrying the line's Item No. SingleInstance state does NOT
        // survive between the line-selection request and the online-validation
        // request (separate device sessions), so we pass the Item No. as a
        // collected step value — includeCollectedValues=true sends it to the
        // ValidateManufactureCode handler.
        _Steps.Create_TextStep(44, 'ItemNo');
        _Steps.Set_defaultValue(L_ItemNo);
        _Steps.Set_visible(false);
        _Steps.Set_optional(true);

        if L_ListValues = '' then begin
            _Steps.Create_TextStep(45, 'ManufactureCode');
            _Steps.Set_defaultValue(L_DefaultValue);
        end else
            _Steps.Create_ListStepFromListValues(45, 'ManufactureCode', '', '', '', L_ListValues, L_DefaultValue);

        _Steps.Set_header('Manufacture Code');
        _Steps.Set_label('Manufacture Code: ');
        _Steps.Set_helpLabel('Select the Manufacture Code');
        _Steps.Set_optional(false);  // Mandatory: operator cannot leave it blank.
        // Online validation: the entered Manufacture Code is validated against the
        // Item Manufacturer Table on the back-end the moment the operator confirms
        // the step. includeCollectedValues=true so the Item No. is available.
        _Steps.Set_onlineValidation('ValidateManufactureCode', true);
    end;

    local procedure BuildManufacturerCodeListValues(_ItemNo: Code[20]): Text
    var
        L_ItemMfr: Record "Item Manufacturer Table";
        L_ListValues: Text;
        L_ItemRef: Record "Item Reference";
    begin
        if _ItemNo = '' then
            exit('');

        // Valid manufacturer codes from the Item Manufacturer Table.
        L_ItemMfr.SetRange("Item No", _ItemNo);
        if L_ItemMfr.FindSet() then
            repeat
                if not ListContainsValue(L_ListValues, L_ItemMfr."Manufacturer code") then
                    L_ListValues += ';' + L_ItemMfr."Manufacturer code";
            until L_ItemMfr.Next() = 0;

        // Also include the manufacturer(s) on the item's Bar Code Item References
        // (e.g. the scanned 1154) so the dropdown can display them. These are not
        // necessarily valid — online validation rejects an invalid pick on confirm.
        /*L_ItemRef.SetRange("Item No.", _ItemNo);
        L_ItemRef.SetRange("Reference Type", L_ItemRef."Reference Type"::"Bar Code");
        L_ItemRef.SetFilter(Manufacturer, '<>%1', '');
        if L_ItemRef.FindSet() then
            repeat
                if not ListContainsValue(L_ListValues, L_ItemRef.Manufacturer) then
                    L_ListValues += ';' + L_ItemRef.Manufacturer;
            until L_ItemRef.Next() = 0;*/

        L_ListValues := DelChr(L_ListValues, '<', ';');  // strip leading separators
        if L_ListValues = '' then
            exit('');

        // Prepend a blank entry so the dropdown shows blank as the first option.
        exit(';' + L_ListValues);
    end;

    // Resolve the C&D Manufacturer Code for the item from the most recent
    // warehouse entry (FEFO: earliest expiry with positive stock).
    // Item Reference.Manufacturer is a free-text GS1 field unrelated to the
    // C&D manufacturer code, so we derive it from warehouse entries instead.
    local procedure GetManufacturerFromBarcode(_ItemNo: Code[20]; _Barcode: Code[50]): Code[100]
    var
        L_ItemRef: Record "Item Reference";
    begin
        if (_ItemNo = '') or (_Barcode = '') then
            exit('');
        L_ItemRef.SetRange("Item No.", _ItemNo);
        L_ItemRef.SetRange("Reference Type", L_ItemRef."Reference Type"::"Bar Code");
        L_ItemRef.SetRange("Reference No.", _Barcode);
        if L_ItemRef.FindFirst() then
            exit(CopyStr(L_ItemRef.Manufacturer, 1, 100));
        exit('');
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnGetRegistrationConfiguration_OnAddSteps', '', true, true)]
    local procedure OnAddSteps_UnplannedCount_ManufactureCode(_RegistrationType: Text; var _HeaderFieldValues: Record "MOB NS Request Element"; var _Steps: Record "MOB Steps Element"; var _RegistrationTypeTracking: Text)
    var
        L_ItemNo: Code[20];
        L_ListValues: Text;
        L_DefaultValue: Text;
    begin
        if _RegistrationType <> 'UnplannedCount' then
            exit;

        L_ItemNo := CopyStr(_HeaderFieldValues.GetValue('Item', false), 1, MaxStrLen(L_ItemNo));
        L_ListValues := BuildManufacturerCodeListValues(L_ItemNo);

        if L_ListValues = '' then begin
            _Steps.Create_TextStep(75, 'ManufactureCode');
            _Steps.Set_defaultValue(L_DefaultValue);
        end else
            _Steps.Create_ListStepFromListValues(75, 'ManufactureCode', '', '', '', L_ListValues, L_DefaultValue);

        _Steps.Set_header('Manufacture Code');
        _Steps.Set_label('Manufacture Code: ');
        _Steps.Set_helpLabel('Select the Manufacture Code');
        _Steps.Set_optional(false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistrationOnUnplannedCount_OnAfterCreateItemJnlLine', '', true, true)]
    local procedure OnAfterCreateItemJnlLine_UnplannedCount_ManufactureCode(var _RequestValues: Record "MOB NS Request Element"; _ReservationEntry: Record "Reservation Entry"; var _ItemJnlLine: Record "Item Journal Line")
    begin
        _ItemJnlLine."Manufacturer Code" := CopyStr(_RequestValues.GetValue('ManufactureCode', false), 1, MaxStrLen(_ItemJnlLine."Manufacturer Code"));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistrationOnUnplannedCount_OnAfterCreateWhseJnlLine', '', true, true)]
    local procedure OnAfterCreateWhseJnlLine_UnplannedCount_ManufactureCode(var _RequestValues: Record "MOB NS Request Element"; var _WhseJnlLine: Record "Warehouse Journal Line")
    begin
        _WhseJnlLine."Manufacturer Code" := CopyStr(_RequestValues.GetValue('ManufactureCode', false), 1, MaxStrLen(_WhseJnlLine."Manufacturer Code"));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Toolbox", 'OnSaveRegistrationValue', '', true, true)]
    local procedure OnSaveRegistrationValue_ManufactureCode(_Path: Text; _Value: Text; var _MobileWMSRegistration: Record "MOB WMS Registration"; var _IsHandled: Boolean)
    var
        L_ItemNo: Code[20];
        L_MfrCode: Code[100];
    begin
        if not (_Path.ToUpper() = 'MANUFACTURECODE') then
            exit;

        if _Value = '' then
            Error(ManufactureCodeMandatoryErr);

        L_ItemNo := _MobileWMSRegistration."Item No.";
        L_MfrCode := CopyStr(_Value, 1, MaxStrLen(L_MfrCode));
        if not ManufacturerExistsInTable(L_ItemNo, L_MfrCode) then
            Error(ManufacturerNotInTableErr, L_MfrCode, L_ItemNo);

        _MobileWMSRegistration."Manufacturer Code" := CopyStr(_Value, 1, MaxStrLen(_MobileWMSRegistration."Manufacturer Code"));
        _IsHandled := true;
    end;

    local procedure ManufacturerExistsInTable(_ItemNo: Code[20]; _MfrCode: Code[100]): Boolean
    var
        L_ItemMfr: Record "Item Manufacturer Table";
    begin
        if (_ItemNo = '') or (_MfrCode = '') then
            exit(false);
        L_ItemMfr.SetRange("Item No", _ItemNo);
        L_ItemMfr.SetRange("Manufacturer code", _MfrCode);
        exit(not L_ItemMfr.IsEmpty());
    end;

    // True if _Value appears as a whole ';'-delimited entry in _ListValues.
    local procedure ListContainsValue(_ListValues: Text; _Value: Text): Boolean
    begin
        if _Value = '' then
            exit(true);  // treat blank as present so it is never added
        exit((';' + _ListValues + ';').Contains(';' + _Value + ';'));
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB Sync. Item Tracking", 'OnAfterCopyTrackingFromMobRegistration', '', true, true)]
    local procedure OnAfterCopyTrackingFromMobRegistration_FlowMfrCode(var _TempReservEntry: Record "Reservation Entry" temporary; _MobRegistration: Record "MOB WMS Registration")
    var
    // L_MfrCode: Code[100];
    begin
        _TempReservEntry."Manufacturer Code" := CopyStr(_MobRegistration."Manufacturer Code", 1, MaxStrLen(_TempReservEntry."Manufacturer Code"));
    end;

    var
        G_ScannedBarcode: Code[50];
        G_MfrCode: Code[100];
        ManufactureCodeMandatoryErr: Label 'Manufacture Code is mandatory. Please scan or type a value.';
        ManufacturerNotInTableErr: Label 'Manufacturer %1 is not valid for Item No. %2.', Comment = '%1 = Manufacturer Code, %2 = Item No.';
}
