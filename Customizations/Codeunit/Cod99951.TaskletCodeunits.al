namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item.Catalog;

codeunit 99951 Tasklet_Codeunits
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Setup Doc. Types", 'OnAfterCreateDefaultDocumentTypes', '', true, true)]
    local procedure RegisterLineSelectionDocumentType()
    var
        MobWmsSetupDocTypes: Codeunit "MOB WMS Setup Doc. Types";
    begin
        MobWmsSetupDocTypes.CreateDocumentType('GetReceiveLineInformation', '', Codeunit::"MOB WMS Whse. Inquiry");
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

        _ResponseElement.Create('select');
        _ResponseElement.SetValue('@name', 'ItemNumber');
        _ResponseElement.SetValue('@value', L_ItemNo);
        if G_MfrCode <> '' then begin
            _ResponseElement.SetValue('values', '');
            _ResponseElement.SetValue('/values/ManufactureCode', G_MfrCode);
        end;

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
        L_ItemNo := CopyStr(_BaseOrderLineElement.Get_ItemNumber(), 1, MaxStrLen(L_ItemNo));
        L_ListValues := BuildManufacturerCodeListValues(L_ItemNo);

        L_DefaultValue := G_MfrCode;

        if L_ListValues = '' then begin
            _Steps.Create_TextStep(45, 'ManufactureCode');
            _Steps.Set_defaultValue(L_DefaultValue);
        end else
            _Steps.Create_ListStepFromListValues(45, 'ManufactureCode', '', '', '', L_ListValues, L_DefaultValue);

        _Steps.Set_header('Manufacture Code');
        _Steps.Set_label('Manufacture Code: ');
        _Steps.Set_helpLabel('Select the Manufacture Code');
        _Steps.Set_optional(false);  // Mandatory: operator cannot leave it blank.
    end;

    local procedure BuildManufacturerCodeListValues(_ItemNo: Code[20]): Text
    var
        L_ItemMfr: Record "Item Manufacturer Table";
        L_ListValues: Text;
    begin
        if _ItemNo = '' then
            exit('');

        L_ItemMfr.SetRange("Item No", _ItemNo);
        if L_ItemMfr.FindSet() then
            repeat
                L_ListValues += ';' + L_ItemMfr."Manufacturer code";
            until L_ItemMfr.Next() = 0;

        exit(DelChr(L_ListValues, '<', ';'));  // strip leading separators
    end;

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


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Toolbox", 'OnSaveRegistrationValue', '', true, true)]
    local procedure OnSaveRegistrationValue_ManufactureCode(_Path: Text; _Value: Text; var _MobileWMSRegistration: Record "MOB WMS Registration"; var _IsHandled: Boolean)
    begin
        if _Path <> 'ManufactureCode' then
            exit;

        if _Value = '' then
            Error(ManufactureCodeMandatoryErr);

        _MobileWMSRegistration."Manufacturer Code" := CopyStr(_Value, 1, MaxStrLen(_MobileWMSRegistration."Manufacturer Code"));
        _IsHandled := true;
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
}
