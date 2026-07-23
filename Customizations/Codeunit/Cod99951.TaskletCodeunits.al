namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Journal;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Item;

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
        L_MfrName: Text;
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

        // The Manufacture Code step's dropdown shows Manufacturer NAMES, so the
        // pre-select value pushed here is the Name mapped from the scanned code
        // (item-specific Name, or the base Manufacturer table Name as fallback so
        // an invalid-for-this-item manufacturer still shows a readable Name).
        // Online validation rejects it if the Name is not valid for the item.
        L_MfrName := GetManufacturerNameFromCode(L_ItemNo, G_MfrCode);

        _ResponseElement.Create('select');
        _ResponseElement.SetValue('@name', 'ItemNumber');
        _ResponseElement.SetValue('@value', L_ItemNo);
        if L_MfrName <> '' then begin
            _ResponseElement.SetValue('values', '');
            _ResponseElement.SetValue('/values/ManufactureCode', L_MfrName);
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
        L_MfrName: Text;
    begin
        if _IsHandled then
            exit;
        if _DocumentType <> 'ValidateManufactureCode' then
            exit;

        // The dropdown shows Manufacturer NAME, so the picked value is a Name.
        L_MfrName := _RequestValues.GetValue('ManufactureCode', false);

        // Item No. comes from the hidden 'ItemNo' step, sent here via
        // includeCollectedValues=true on the Manufacture Code step's online validation.
        L_ItemNo := CopyStr(_RequestValues.GetValue('ItemNo', false), 1, MaxStrLen(L_ItemNo));

        // Valid only if the picked Name maps to a Manufacturer Code for the item.
        if GetManufacturerCodeFromName(L_ItemNo, L_MfrName) = '' then
            Error(ManufacturerNotInTableErr, L_MfrName, L_ItemNo);

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

        _Steps.Set_header('Manufacturer Name');
        _Steps.Set_label('Manufacturer Name: ');
        _Steps.Set_helpLabel('Select the Manufacture.');
        _Steps.Set_optional(false);  // Mandatory: operator cannot leave it blank.
        // Online validation: the entered Manufacture Code is validated against the
        // Item Manufacturer Table on the back-end the moment the operator confirms
        // the step. includeCollectedValues=true so the Item No. is available.
        _Steps.Set_onlineValidation('ValidateManufactureCode', true);
    end;

    internal procedure BuildManufacturerCodeListValues(_ItemNo: Code[20]): Text
    var
        L_ItemMfr: Record "Item Manufacturer Table";
        L_ListValues: Text;
    begin
        if _ItemNo = '' then
            exit('');

        // Show the Manufacturer NAME in the dropdown (the picked Name is mapped
        // back to its Code at validation/save time via GetManufacturerCodeFromName).
        L_ItemMfr.SetRange("Item No", _ItemNo);
        if L_ItemMfr.FindSet() then
            repeat
                if not ListContainsValue(L_ListValues, L_ItemMfr."Manufacturer Name") then
                    L_ListValues += ';' + L_ItemMfr."Manufacturer Name";
            until L_ItemMfr.Next() = 0;

        // NOTE: only the item's valid manufacturers (Item Manufacturer Table) are
        // listed. A scanned manufacturer that is NOT valid for the item is
        // deliberately kept OUT of the list, so the operator must pick a valid one.

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


    // NOTE: The Unplanned Count Manufacture Code subscribers (add-step + post to
    // Item/Warehouse Journal Line) now live in Cod99955 "Unplanned Count Reason
    // Code", which owns all Unplanned Count registration logic. They call the
    // shared Manufacturer helpers below (now internal) because the Receive flow in
    // this codeunit also uses them. OnSaveRegistrationValue_ManufactureCode stays
    // here — it is a global save hook that fires for both the Receive and the
    // Unplanned Count flows (keyed on the 'ManufactureCode' path, not the flow).

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Toolbox", 'OnSaveRegistrationValue', '', true, true)]
    local procedure OnSaveRegistrationValue_ManufactureCode(_Path: Text; _Value: Text; var _MobileWMSRegistration: Record "MOB WMS Registration"; var _IsHandled: Boolean)
    var
        L_MfrCode: Code[100];
        L_ItemNo: Code[20];
    begin
        // The hidden 'ItemNo' step (id 44) fires here BEFORE the 'ManufactureCode'
        // step (id 45) within the same SaveRegistrationData loop. Capture it into a
        // SingleInstance var so it is available when ManufactureCode is saved —
        // the registration's own "Item No." field is not populated at this point.
        if _Path.ToUpper() = 'ITEMNO' then begin
            G_SaveItemNo := CopyStr(_Value, 1, MaxStrLen(G_SaveItemNo));
            exit;
        end;

        if not (_Path.ToUpper() = 'MANUFACTURECODE') then
            exit;

        if _Value = '' then
            Error(ManufactureCodeMandatoryErr);

        // Item No. from the hidden step (captured above), with fallbacks.
        L_ItemNo := G_SaveItemNo;
        if L_ItemNo = '' then
            L_ItemNo := _MobileWMSRegistration."Item No.";
        if L_ItemNo = '' then
            L_ItemNo := GetItemNoFromBarcode(_MobileWMSRegistration.LineSelectionValue);

        // The dropdown value is the Manufacturer NAME; store the mapped Code.
        L_MfrCode := GetManufacturerCodeFromName(L_ItemNo, _Value);
        if L_MfrCode = '' then
            Error(ManufacturerNotInTableErr, _Value, L_ItemNo);

        _MobileWMSRegistration."Manufacturer Code" := CopyStr(L_MfrCode, 1, MaxStrLen(_MobileWMSRegistration."Manufacturer Code"));
        _IsHandled := true;
    end;

    /*local procedure ManufacturerExistsInTable(_ItemNo: Code[20]; _MfrCode: Code[100]): Boolean
    var
        L_ItemMfr: Record "Item Manufacturer Table";
    begin
        if (_ItemNo = '') or (_MfrCode = '') then
            exit(false);
        L_ItemMfr.SetRange("Item No", _ItemNo);
        L_ItemMfr.SetRange("Manufacturer code", _MfrCode);
        exit(not L_ItemMfr.IsEmpty());
    end;*/

    // The dropdown shows Manufacturer NAME; resolve it back to the Manufacturer
    // Code for the item. Returns '' if the name is not set up for the item.
    internal procedure GetManufacturerCodeFromName(_ItemNo: Code[20]; _MfrName: Text): Code[100]
    var
        L_ItemMfr: Record "Item Manufacturer Table";
    begin
        if (_ItemNo = '') or (_MfrName = '') then
            exit('');
        L_ItemMfr.SetRange("Item No", _ItemNo);
        L_ItemMfr.SetRange("Manufacturer Name", CopyStr(_MfrName, 1, MaxStrLen(L_ItemMfr."Manufacturer Name")));
        if L_ItemMfr.FindFirst() then
            exit(L_ItemMfr."Manufacturer code");
        exit('');
    end;

    // Resolve the Manufacturer NAME for a Manufacturer Code + item (the dropdown
    // shows Names, so the pre-select value pushed on scan must be a Name).
    // Prefers the item-specific Name (Item Manufacturer Table); if the code is not
    // linked to the item, falls back to the base Manufacturer table (5720) so an
    // invalid-for-this-item code still shows a readable Name (validation rejects it).
    internal procedure GetManufacturerNameFromCode(_ItemNo: Code[20]; _MfrCode: Code[100]): Text
    var
        L_ItemMfr: Record "Item Manufacturer Table";
        L_Manufacturer: Record Manufacturer;
    begin
        if _MfrCode = '' then
            exit('');
        if _ItemNo <> '' then begin
            L_ItemMfr.SetRange("Item No", _ItemNo);
            L_ItemMfr.SetRange("Manufacturer code", _MfrCode);
            if L_ItemMfr.FindFirst() then
                exit(L_ItemMfr."Manufacturer Name");
        end;
        // Fallback: base Manufacturer table.
        if L_Manufacturer.Get(_MfrCode) then
            exit(L_Manufacturer.Name);
        exit('');
    end;

    internal procedure GetManufacturerName(_MfrCode: Code[100]): Text
    var
        L_MfrRec: Record Manufacturer;
        L_Manufacturer: Record Manufacturer;
    begin
        if _MfrCode = '' then
            exit('');

        L_MfrRec.SetRange(Code, _MfrCode);
        if L_MfrRec.FindFirst() then
            exit(L_MfrRec.Name);

        // Fallback: base Manufacturer table.
        if L_Manufacturer.Get(_MfrCode) then
            exit(L_Manufacturer.Name);
        exit('');
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
        _TempReservEntry."Manufacturer Name" := CopyStr(GetManufacturerName(_MobRegistration."Manufacturer Code"), 1, MaxStrLen(_TempReservEntry."Manufacturer Name"));
    end;

    var
        G_ScannedBarcode: Code[50];
        G_MfrCode: Code[100];
        G_SaveItemNo: Code[20];  // Item No. from the hidden 'ItemNo' step, captured during OnSaveRegistrationValue
        ManufactureCodeMandatoryErr: Label 'Manufacture Code is mandatory. Please scan or type a value.';
        ManufacturerNotInTableErr: Label 'Manufacturer %1 is not valid for Item No. %2.', Comment = '%1 = Manufacturer Code, %2 = Item No.';
}
