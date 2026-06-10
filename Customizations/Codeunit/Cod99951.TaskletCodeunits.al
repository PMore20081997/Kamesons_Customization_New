namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item.Catalog;

codeunit 99951 Tasklet_Codeunits
{
    // ---------------------------------------------------------------------
    // Manufacture Code step — Receive Order Lines.
    // Added via the MOB WMS Receive "add steps" event, following the same
    // Create_TextStep / OnSaveRegistrationValue pattern used for custom steps.
    // ---------------------------------------------------------------------

    // Create the custom "ManufactureCode" step on the Receive Order Lines
    // screen as a dropdown (List step) from the Item Manufacturer Table for the
    // line's Item No. The displayed default is the single-manufacturer item
    // default (the scanned barcode is not available when steps are built, so it
    // cannot drive the displayed default — it is applied to the stored value at
    // save instead; see OnAfterCopyTrackingFromMobRegistration_FlowMfrCode).
    //
    // Steps are sorted by Id (application.cfg: stepSorting="ById").
    // Standard step Ids: Expiration 31, Lot 32, Package No. 37, Serial 40,
    // Quantity 50, Quantity-by-scan 51. Id 45 places Manufacture Code between
    // Package No. (37) and Serial/Quantity.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Receive", 'OnGetReceiveOrderLines_OnAddStepsToAnyLine', '', true, true)]
    local procedure My02OnGetReceiveOrderLines_OnAddManufactureCodeStep(_RecRef: RecordRef; var _BaseOrderLineElement: Record "MOB NS BaseDataModel Element"; var _Steps: Record "MOB Steps Element")
    var
        L_ItemNo: Code[20];
        L_ListValues: Text;
        L_DefaultValue: Text;
    begin
        L_ItemNo := CopyStr(_BaseOrderLineElement.Get_ItemNumber(), 1, MaxStrLen(L_ItemNo));
        L_ListValues := BuildManufacturerCodeListValues(L_ItemNo);
        L_DefaultValue := GetSingleRefManufacturerDefault(L_ItemNo);

        // No manufacturers configured for this item -> fall back to a free-text
        // step so the operator is not blocked by an empty dropdown.
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

    // Build-time default for the dropdown: the Manufacturer is returned only
    // when the item has EXACTLY ONE Bar Code Item Reference with a non-blank
    // Manufacturer (i.e. the item maps to a single manufacturer). For items with
    // multiple Bar Code references / manufacturers we cannot know which barcode
    // will be scanned at build time, so we return blank and let the operator
    // pick (the scanned value is applied to the stored value at save).
    local procedure GetSingleRefManufacturerDefault(_ItemNo: Code[20]): Text
    var
        L_ItemRef: Record "Item Reference";
        L_FoundMfr: Code[100];
    begin
        if _ItemNo = '' then
            exit('');

        L_ItemRef.SetRange("Item No.", _ItemNo);
        L_ItemRef.SetRange("Reference Type", L_ItemRef."Reference Type"::"Bar Code");
        L_ItemRef.SetFilter(Manufacturer, '<>%1', '');
        if L_ItemRef.FindSet() then
            repeat
                if (L_FoundMfr <> '') and (L_ItemRef.Manufacturer <> L_FoundMfr) then
                    exit('');  // more than one distinct manufacturer -> ambiguous
                L_FoundMfr := CopyStr(L_ItemRef.Manufacturer, 1, MaxStrLen(L_FoundMfr));
            until L_ItemRef.Next() = 0;

        exit(L_FoundMfr);
    end;

    // Build a ';'-separated list of Manufacturer Codes from the Item
    // Manufacturer Table for the given item.
    // Note: listValues is Text[250]; very long lists are truncated by the field.
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

    // Save the selected/typed "ManufactureCode" value onto the Mobile WMS
    // Registration (mandatory). The final stored value is decided at save in
    // OnAfterCopyTrackingFromMobRegistration_FlowMfrCode.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Toolbox", 'OnSaveRegistrationValue', '', true, true)]
    local procedure OnSaveRegistrationValue_ManufactureCode(_Path: Text; _Value: Text; var _MobileWMSRegistration: Record "MOB WMS Registration"; var _IsHandled: Boolean)
    begin
        if _Path <> 'ManufactureCode' then
            exit;

        // Mandatory: reject a blank value server-side as a backstop to the
        // mobile step's optional=false (older clients / replayed payloads).
        if _Value = '' then
            Error(ManufactureCodeMandatoryErr);

        _MobileWMSRegistration."Manufacturer Code" := CopyStr(_Value, 1, MaxStrLen(_MobileWMSRegistration."Manufacturer Code"));
        _IsHandled := true;
    end;

    // Set the Manufacturer Code on the reservation entry the receive posting
    // creates. The scanned barcode wins: resolve the manufacturer from the
    // barcode the operator scanned to select the line (Item Reference, type
    // Bar Code) and use it; only when that resolves nothing do we fall back to
    // the value the operator selected on the dropdown.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB Sync. Item Tracking", 'OnAfterCopyTrackingFromMobRegistration', '', true, true)]
    local procedure OnAfterCopyTrackingFromMobRegistration_FlowMfrCode(var _TempReservEntry: Record "Reservation Entry" temporary; _MobRegistration: Record "MOB WMS Registration")
    var
        //L_MfrCode: Code[100];
    begin
        // L_MfrCode := ResolveManufacturerFromScannedBarcode(_MobRegistration);
        // if L_MfrCode = '' then
        //     L_MfrCode := _MobRegistration."Manufacturer Code";
        // if L_MfrCode = '' then
        //     exit;

        // Reservation Entry."Manufacturer Code" (from C&D) is Code[20]; truncate.
        // _TempReservEntry."Manufacturer Code" := CopyStr(L_MfrCode, 1, MaxStrLen(_TempReservEntry."Manufacturer Code"));
        _TempReservEntry."Manufacturer Code" := CopyStr(_MobRegistration."Manufacturer Code", 1, MaxStrLen(_TempReservEntry."Manufacturer Code"));
    end;

    // Resolve the Manufacturer from the barcode the operator scanned to select
    // the line. The full barcode is read from the registration XML (the
    // persisted LineSelectionValue field is only Code[20] and truncates longer
    // barcodes); it matches an Item Reference of type "Bar Code" for the line's
    // item, whose custom "Manufacturer" field (C&D) holds the code. Returns ''
    // if there is no scanned barcode or no matching reference.
    // local procedure ResolveManufacturerFromScannedBarcode(_MobRegistration: Record "MOB WMS Registration"): Code[100]
    // var
    //     L_ItemRef: Record "Item Reference";
    //     L_Barcode: Text;
    // begin
    //     if _MobRegistration."Item No." = '' then
    //         exit('');

    //     L_Barcode := GetScannedBarcode(_MobRegistration);
    //     if L_Barcode = '' then
    //         exit('');

    //     L_ItemRef.SetRange("Item No.", _MobRegistration."Item No.");
    //     L_ItemRef.SetRange("Reference Type", L_ItemRef."Reference Type"::"Bar Code");
    //     L_ItemRef.SetRange("Reference No.", CopyStr(L_Barcode, 1, MaxStrLen(L_ItemRef."Reference No.")));
    //     if L_ItemRef.FindFirst() then
    //         exit(L_ItemRef.Manufacturer);
    //     exit('');
    // end;

    // Return the scanned line-selection barcode at full length. The persisted
    // LineSelectionValue field is only Code[20] and truncates longer barcodes,
    // so read the original 'lineSelectionValue' attribute from the registration
    // XML (MOB WMS saves the whole registration node — see SetRegistrationXml).
    // Falls back to the field if the XML is unavailable.
    // local procedure GetScannedBarcode(_MobRegistration: Record "MOB WMS Registration"): Text
    // var
    //     L_MobXmlMgt: Codeunit "MOB XML Management";
    //     L_RegXmlDoc: XmlDocument;
    //     L_RootElement: XmlElement;
    //     L_RootNode: XmlNode;
    //     L_Value: Text;
    // begin
    //     if _MobRegistration.GetRegistrationXmlAsXmlDoc(L_RegXmlDoc) then begin
    //         L_RegXmlDoc.GetRoot(L_RootElement);
    //         L_RootNode := L_RootElement.AsXmlNode();
    //         if L_MobXmlMgt.GetAttribute(L_RootNode, 'lineSelectionValue', L_Value) then
    //             if L_Value <> '' then
    //                 exit(L_Value);
    //     end;

    //     exit(_MobRegistration.LineSelectionValue);  // fallback (Code[20])
    // end;

    var
        ManufactureCodeMandatoryErr: Label 'Manufacture Code is mandatory. Please scan or type a value.';
}
