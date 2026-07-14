namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;
using Microsoft.Inventory.Counting.Recording;
using Microsoft.Inventory.Item.Catalog;

// -------------------------------------------------------------------------------------
// Phys. Invt. Recording on Tasklet Mobile WMS — Manufacturer Name step + flow to entries.
//
// Adds two steps to each recording line (via OnGetPhysInvtRecordingLines_OnAddStepsToPhysInvtRecordLine):
//   * PackageNumber (id 55) — a Package No. step WE create in AL, carrying the online
//     validation. The operator scans/enters it; it is used as an extra filter for the
//     manufacturer lookup. Because it is an AL-created step, Set_onlineValidation works
//     directly on it (no cfg tweak needed).
//   * PhysInvtMfrName (id 60) — display shows the Manufacturer NAME. The Package No.
//     validation pushes the resolved value onto it (60 > 55 — a valid forward write).
//     Named PhysInvtMfrName (NOT 'ManufactureCode') so the global
//     OnSaveRegistrationValue_ManufactureCode hook in Cod99951 does not catch and
//     wrongly validate it.
//
// On Package No. confirm, the PhysInvtRecPkgValidation online validation resolves the
// Manufacturer from the counted stock's Warehouse Entries (Item + Bin + UoM + Lot +
// Package) and pushes the Manufacturer NAME onto the PhysInvtMfrName step.
//
// FLOW TO ENTRIES: the recording posts through Phys. Invt. Order → Item Journal, which
// creates a Reservation Entry (337) for the lot. Standard BC leaves its Manufacturer
// Code blank. FillReservEntryMfrCode fills it by lot — SCOPED to the Phys. Invt. Order
// Line source (Source Type 5877) so no other flow is affected — and from there the
// existing Warehouse Entry / ILE OnBeforeInsert subscribers (Cod99964) carry it onward.
//
// The Name<-Code mapping is reused from Cod99951 (Tasklet_Codeunits); the lot lookup
// from Cod99965 (Kam Reservation Mgt.).
// -------------------------------------------------------------------------------------

codeunit 99958 "Phys Invt Rec. Manufacture"
{
    Access = Public;

    // ---------- Register the online-validation document type ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Setup Doc. Types", 'OnAfterCreateDefaultDocumentTypes', '', true, true)]
    local procedure RegisterPhysInvtRecDocTypes()
    var
        L_MobWmsSetupDocTypes: Codeunit "MOB WMS Setup Doc. Types";
    begin
        L_MobWmsSetupDocTypes.CreateDocumentType('PhysInvtRecPkgValidation', '', Codeunit::"MOB WMS Whse. Inquiry");
    end;

    // ---------- Add the Package No. + Manufacturer Name steps to the recording line ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Phys Invt Recording", 'OnGetPhysInvtRecordingLines_OnAddStepsToPhysInvtRecordLine', '', true, true)]
    local procedure OnAddStepsToLine_PhysInvtRec(_PhysInvtRecordLine: Record "Phys. Invt. Record Line"; var _BaseOrderLineElement: Record "MOB NS BaseDataModel Element"; var _Steps: Record "MOB Steps Element")
    begin
        // Package No. step (id 45) — WE own it, so we can attach online validation.
        // Placed BEFORE Quantity (built-in id 50). The operator scans/enters it; it
        // feeds the manufacturer lookup as a filter. includeCollectedValues=true so
        // Bin/Lot and the line identity reach the handler.
        _Steps.Create_TextStep(45, 'PackageNumber');
        _Steps.Set_header('Package No.');
        _Steps.Set_label('Package No.: ');
        _Steps.Set_helpLabel('Scan or enter the Package No.');
        _Steps.Set_optional(false);
        _Steps.Set_onlineValidation('PhysInvtRecPkgValidation', true);

        // Manufacturer Name step (id 46) — the write target for the Package No.
        // validation (46 > 45, and still before Quantity 50). Distinct name keeps it
        // out of Cod99951's ManufactureCode hook.
        _Steps.Create_TextStep(46, 'PhysInvtMfrName');
        _Steps.Set_header('Manufacturer Name');
        _Steps.Set_label('Manufacturer Name: ');
        _Steps.Set_helpLabel('Manufacturer for the counted stock');
        _Steps.Set_optional(false);
    end;

    // ---------- Online validation: resolve the manufacturer on Package No. ----------

    // Fires when the operator confirms the Package No. step. The request identifies the
    // recording line by backendId (RecordingNo-OrderNo) + lineNumber. Resolve Item +
    // Bin + UoM from the Phys. Invt. Record Line, read Lot + Package from the request,
    // filter Warehouse Entry, map the Manufacturer Code to its Name, and write the Name
    // onto the PhysInvtMfrName step (id 60) via 'stepUpdates'.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Whse. Inquiry", 'OnWhseInquiryOnCustomDocumentType', '', true, true)]
    local procedure OnWhseInquiry_PhysInvtRecPkgValidation(_DocumentType: Text; var _RequestValues: Record "MOB NS Request Element"; var _ResponseElement: Record "MOB NS Resp Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        L_TaskletCodeunits: Codeunit Tasklet_Codeunits;
        L_ItemNo: Code[20];
        L_BinCode: Code[20];
        L_UomCode: Code[10];
        L_LotNo: Text;
        L_PackageNo: Text;
        L_MfrCode: Code[100];
        L_MfrName: Text;
    begin
        if _IsHandled then
            exit;
        if _DocumentType <> 'PhysInvtRecPkgValidation' then
            exit;

        // Item / Bin / UoM come from the recording line; Lot / Package are collected.
        ResolveLineStock(_RequestValues, L_ItemNo, L_BinCode, L_UomCode);
        L_LotNo := _RequestValues.Get_LotNumber();
        if L_LotNo = '' then
            L_LotNo := GetRequestValue(_RequestValues, 'LotNumber', 'Lot No.');
        L_PackageNo := GetRequestValue(_RequestValues, 'PackageNumber', 'Package No.');

        L_MfrCode := LookupManufacturerCodeFromWhseEntries(L_ItemNo, L_BinCode, L_UomCode, L_LotNo, L_PackageNo);
        // The step shows Manufacturer NAMES — map the Code to its Name.
        L_MfrName := L_TaskletCodeunits.GetManufacturerName(L_MfrCode);

        if L_MfrName <> '' then begin
            _ResponseElement.Create('stepUpdates');
            _ResponseElement.SetValue('step/@name', 'PhysInvtMfrName');
            _ResponseElement.SetValue('step/@value', L_MfrName);
            _ResponseElement.SetValue('step/@interactionPermission', Format(Enum::"MOB ValueInteractionPermission"::AllowEdit));
        end;

        _IsHandled := true;
    end;

    // ---------- Capture the operator's values onto the registration ----------

    // Store what the operator actually scanned/confirmed onto the MOB WMS Registration,
    // so it flows to the Reservation Entry via the standard item-tracking sync:
    //   * PhysInvtMfrName — the confirmed Manufacturer NAME, mapped to its Code via the
    //     Manufacturer table (5720). The existing Cod99951 subscriber
    //     OnAfterCopyTrackingFromMobRegistration copies Registration."Manufacturer Code"
    //     onto the Reservation Entry, and Cod99964 carries it to Warehouse Entry / ILE.
    //   * PackageNumber — the scanned Package No. is already a standard registration
    //     field, populated by the scan, so it flows via standard tracking; we set it
    //     here too as a safeguard in case only our step carried it.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Toolbox", 'OnSaveRegistrationValue', '', true, true)]
    local procedure OnSaveRegistrationValue_PhysInvtRec(_Path: Text; _Value: Text; var _MobileWMSRegistration: Record "MOB WMS Registration"; var _IsHandled: Boolean)
    begin
        case _Path.ToUpper() of
            'PHYSINVTMFRNAME':
                begin
                    // Operator confirmed a Manufacturer NAME — store the mapped Code.
                    _MobileWMSRegistration."Manufacturer Code" :=
                        CopyStr(GetManufacturerCodeFromName(_Value), 1, MaxStrLen(_MobileWMSRegistration."Manufacturer Code"));
                    _IsHandled := true;
                end;
            'PACKAGENUMBER':
                begin
                    _MobileWMSRegistration.PackageNumber :=
                        CopyStr(_Value, 1, MaxStrLen(_MobileWMSRegistration.PackageNumber));
                    _IsHandled := true;
                end;
        end;
    end;

    // Map a Manufacturer NAME to its Code via the Manufacturer table (5720).
    local procedure GetManufacturerCodeFromName(_MfrName: Text): Code[100]
    var
        L_Manufacturer: Record Manufacturer;
    begin
        if _MfrName = '' then
            exit('');
        L_Manufacturer.SetRange(Name, CopyStr(_MfrName, 1, MaxStrLen(L_Manufacturer.Name)));
        if L_Manufacturer.FindFirst() then
            exit(L_Manufacturer.Code);
        exit('');
    end;

    // ---------- Helpers ----------

    // Resolve Item + Bin + UoM from the Phys. Invt. Record Line the request refers to.
    // The recording BackendID is 'RecordingNo-OrderNo'; the line is keyed by
    // Order No. + Recording No. + Line No.
    local procedure ResolveLineStock(var _RequestValues: Record "MOB NS Request Element"; var _ItemNo: Code[20]; var _BinCode: Code[20]; var _UomCode: Code[10])
    var
        L_MobWmsToolbox: Codeunit "MOB WMS Toolbox";
        L_PhysInvtRecordLine: Record "Phys. Invt. Record Line";
        L_BackendID: Text;
        L_LineNoText: Text;
        L_OrderNo: Code[20];
        L_RecordingNo: Integer;
        L_LineNo: Integer;
    begin
        L_BackendID := GetRequestValue(_RequestValues, 'backendId', 'BackendID');
        if L_BackendID = '' then
            L_BackendID := _RequestValues.Get_OrderBackendID();

        L_LineNoText := GetRequestValue(_RequestValues, 'lineNumber', 'LineNumber');
        if L_LineNoText = '' then
            L_LineNoText := _RequestValues.Get_LineNumber();
        if not Evaluate(L_LineNo, L_LineNoText) then
            L_LineNo := 0;

        if (L_BackendID = '') or (L_LineNo = 0) then
            exit;

        L_MobWmsToolbox.GetOrderNoAndRecordingNoFromBackendId(CopyStr(L_BackendID, 1, 40), L_OrderNo, L_RecordingNo);

        L_PhysInvtRecordLine.SetRange("Order No.", L_OrderNo);
        L_PhysInvtRecordLine.SetRange("Recording No.", L_RecordingNo);
        L_PhysInvtRecordLine.SetRange("Line No.", L_LineNo);
        if L_PhysInvtRecordLine.FindFirst() then begin
            _ItemNo := L_PhysInvtRecordLine."Item No.";
            _BinCode := L_PhysInvtRecordLine."Bin Code";
            _UomCode := L_PhysInvtRecordLine."Unit of Measure Code";
        end;
    end;

    // Manufacturer Code from the Warehouse Entries for the counted stock: Item + Bin +
    // UoM (from the line) + Lot + Package (collected). Each filter is applied only when
    // present. Last matching entry with a non-blank Manufacturer Code wins.
    local procedure LookupManufacturerCodeFromWhseEntries(_ItemNo: Code[20]; _BinCode: Code[20]; _UomCode: Code[10]; _LotNo: Text; _PackageNo: Text): Code[100]
    var
        L_WhseEntry: Record "Warehouse Entry";
    begin
        if _ItemNo = '' then
            exit('');

        L_WhseEntry.SetRange("Item No.", _ItemNo);
        if _BinCode <> '' then
            L_WhseEntry.SetRange("Bin Code", _BinCode);
        if _UomCode <> '' then
            L_WhseEntry.SetRange("Unit of Measure Code", _UomCode);
        if _LotNo <> '' then
            L_WhseEntry.SetRange("Lot No.", CopyStr(_LotNo, 1, MaxStrLen(L_WhseEntry."Lot No.")));
        if _PackageNo <> '' then
            L_WhseEntry.SetRange("Package No.", CopyStr(_PackageNo, 1, MaxStrLen(L_WhseEntry."Package No.")));
        L_WhseEntry.SetFilter("Manufacturer Code", '<>%1', '');
        if L_WhseEntry.FindLast() then
            exit(L_WhseEntry."Manufacturer Code");
        exit('');
    end;

    // Read a request value by its primary key, falling back to an alternate key.
    local procedure GetRequestValue(var _RequestValues: Record "MOB NS Request Element"; _PrimaryKey: Text; _FallbackKey: Text): Text
    var
        L_Value: Text;
    begin
        L_Value := CopyStr(_RequestValues.GetValue(_PrimaryKey, false), 1, 250);
        if L_Value = '' then
            L_Value := CopyStr(_RequestValues.GetValue(_FallbackKey, false), 1, 250);
        exit(L_Value);
    end;
}
