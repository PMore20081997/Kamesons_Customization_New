namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;
using Microsoft.Inventory.Journal;
using Microsoft.Warehouse.Journal;
using Microsoft.Inventory.Tracking;

// -------------------------------------------------------------------------------------
// Unplanned Count on Tasklet Mobile WMS — Manufacture Code default.
//
// Adds a "Manufacture Code" step (id 75) to the Unplanned Count flow. Its value is
// resolved by online validation (GetUnplannedCountManufactureCode) attached to the
// built-in Quantity step (id 70): when the operator confirms Quantity, the
// Manufacturer Code recorded on the counted stock's Warehouse Entries — matched by
// Item + To Bin + Unit of Measure + Lot + Package — is resolved and pushed FORWARD
// onto the Manufacture Code step (id 75).
//
// Step ordering (Tasklet built-in Unplanned Count flow): Bin 10, Variant 20,
// UoM 30, Lot/Package 40+, Quantity 70, [built-in Reason Code 80]. Validation runs
// on Quantity (70) — after Bin/UoM/Lot/Package are collected — and online
// validation may write to the calling step or steps with a HIGHER id, so it can
// populate ManufactureCode (75 > 70). Validating on the id-75 step itself would be
// too early only if earlier values were missing; here everything up to 70 is set.
//
// Reason Code is NOT added here: Tasklet ships a built-in Reason Code step (id 80)
// for Unplanned Count, enabled by the "Require Reason Code Unpl. Cnt." setting on
// MOB Setup. Enable that setting instead of duplicating it.
//
// The Manufacture Code Name/Code mapping helpers live in Cod99951
// (Tasklet_Codeunits) because the Receive flow there uses them too; they are
// exposed as `internal` procedures and called from here. The global
// OnSaveRegistrationValue hook for Manufacture Code also stays in Cod99951 — it
// fires for both the Receive and the Unplanned Count flows.
// -------------------------------------------------------------------------------------

codeunit 99955 "Unplanned Count Reason Code"
{
    Access = Public;

    // Register the online-validation document type used by the Manufacture Code
    // step. It resolves the Manufacture Code from Warehouse Entries when the
    // operator reaches the step, and pushes it back as the step value.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Setup Doc. Types", 'OnAfterCreateDefaultDocumentTypes', '', true, true)]
    local procedure RegisterUnplannedCountDocTypes()
    var
        L_MobWmsSetupDocTypes: Codeunit "MOB WMS Setup Doc. Types";
    begin
        L_MobWmsSetupDocTypes.CreateDocumentType('GetUnplannedCountManufactureCode', '', Codeunit::"MOB WMS Whse. Inquiry");
    end;

    // Online validation attached to the built-in Quantity step (id 70) of the
    // Unplanned Count flow. Fires when the operator enters/confirms Quantity — by
    // then the earlier steps (Bin 10, UoM 30, Lot/Package 40+) are collected and,
    // with includeCollectedValues=true, arrive in _RequestValues.
    //
    // Use those collected values to filter Warehouse Entry, get the Manufacturer
    // Code, map it to the Manufacturer NAME, and push the Name forward onto the
    // Manufacture Code step (id 75) via the named-element response (the child node
    // name IS the step name — same shape as the built-in GetSerialNumberInformation).
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Whse. Inquiry", 'OnWhseInquiryOnCustomDocumentType', '', true, true)]
    local procedure OnWhseInquiry_GetUnplannedCountManufactureCode(_DocumentType: Text; var _RequestValues: Record "MOB NS Request Element"; var _ResponseElement: Record "MOB NS Resp Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        L_TaskletCodeunits: Codeunit Tasklet_Codeunits;
        L_ItemNo: Code[20];
        L_MfrCode: Code[100];
        L_MfrName: Text;
    begin
        if _IsHandled then
            exit;
        if _DocumentType <> 'GetUnplannedCountManufactureCode' then
            exit;

        L_ItemNo := CopyStr(_RequestValues.Get_ItemNumber(), 1, MaxStrLen(L_ItemNo));
        if L_ItemNo = '' then
            L_ItemNo := CopyStr(GetRequestValue(_RequestValues, 'Item', 'ItemNumber'), 1, MaxStrLen(L_ItemNo));

        // Filter Warehouse Entry by the collected Item + Bin + UoM + Lot + Package.
        L_MfrCode := LookupManufacturerCodeFromWhseEntries(_RequestValues, L_ItemNo);
        // The step shows Manufacturer NAMES — map the Code to its Name.
        L_MfrName := L_TaskletCodeunits.GetManufacturerName(L_MfrCode);

        if L_MfrName <> '' then begin
            // Write the value onto the ManufactureCode step (id 75) via the
            // documented 'stepUpdates' response — the shape that populates a step
            // from an online validation. AllowEdit so the operator can still change it.
            _ResponseElement.Create('stepUpdates');
            _ResponseElement.SetValue('step/@name', 'ManufactureCode');
            _ResponseElement.SetValue('step/@value', L_MfrName);
            _ResponseElement.SetValue('step/@interactionPermission', Format(Enum::"MOB ValueInteractionPermission"::AllowEdit));
        end;

        _IsHandled := true;
    end;

    // ---------- 1. Add the Manufacture Code step to the Unplanned Count flow ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnGetRegistrationConfiguration_OnAddSteps', '', true, true)]
    local procedure OnAddSteps_UnplannedCount(_RegistrationType: Text; var _HeaderFieldValues: Record "MOB NS Request Element"; var _Steps: Record "MOB Steps Element"; var _RegistrationTypeTracking: Text)
    begin
        if _RegistrationType <> 'UnplannedCount' then
            exit;

        // Manufacture Code step (id 75). Its value is resolved and pushed FORWARD
        // onto this step by the online validation attached to the built-in Quantity
        // step (id 70) — see OnAfterAddStep_AttachQuantityValidation. Validating on
        // Quantity (70) rather than here guarantees Bin/UoM/Lot/Package (10..40+) are
        // all collected first, and 75 > 70 so the handler is allowed to write here.
        // The step's internal name stays 'ManufactureCode' — it is the collected-value
        // key targeted by the stepUpdates response and read by the post handlers.
        // Only the operator-facing header/label show "Manufacturer Name".
        _Steps.Create_TextStep(75, 'ManufactureCode');
        _Steps.Set_header('Manufacturer Name');
        _Steps.Set_label('Manufacturer Name: ');
        _Steps.Set_helpLabel('Manufacturer for the counted stock');
        _Steps.Set_optional(false);
    end;

    // Attach the online validation to the built-in Quantity step (id 70). The
    // Quantity step is created by Tasklet (Create_DecimalStep_Quantity), so we can't
    // call Set_onlineValidation when building it — we find it here, after all steps
    // are added, and attach the validation. When the operator confirms Quantity, the
    // GetUnplannedCountManufactureCode handler fires with Bin/UoM/Lot/Package already
    // collected and writes the resolved value forward onto ManufactureCode (id 75).
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnGetRegistrationConfiguration_OnAfterAddStep', '', true, true)]
    local procedure OnAfterAddStep_AttachQuantityValidation(_RegistrationType: Text; var _HeaderFieldValues: Record "MOB NS Request Element"; var _Step: Record "MOB Steps Element")
    begin
        if _RegistrationType <> 'UnplannedCount' then
            exit;
        if _Step.Get_name() <> 'Quantity' then
            exit;

        _Step.Set_onlineValidation('GetUnplannedCountManufactureCode', true);
        _Step.Save();
    end;

    // Default Manufacturer Code for the count line, taken from the existing
    // Warehouse Entries for the stock being counted. The request identifies that
    // stock selected on the Unplanned Count screen (Item + To Bin + Unit of Measure
    // + Lot + Package). Each filter is applied only when the request carries that
    // value, so the lookup narrows as far as the values allow and still works when
    // only the Item is known. The last matching entry with a non-blank Manufacturer
    // Code wins (mirrors LookupManufacturerCodeByLot).
    local procedure LookupManufacturerCodeFromWhseEntries(var _RequestValues: Record "MOB NS Request Element"; _ItemNo: Code[20]): Code[100]
    var
        L_WhseEntry: Record "Warehouse Entry";
        L_BinCode: Text;
        L_UomCode: Text;
        L_LotNo: Text;
        L_PackageNo: Text;
    begin
        if _ItemNo = '' then
            exit('');

        // Prefer the documented request accessors (Get_Bin / Get_LotNumber); fall
        // back to GetValue by node name for the fields with no dedicated accessor
        // (UoM, Package). Node names confirmed from the Mobile Document Queue.
        L_BinCode := _RequestValues.Get_Bin();
        if L_BinCode = '' then
            L_BinCode := GetRequestValue(_RequestValues, 'Bin', 'BinCode');
        L_LotNo := _RequestValues.Get_LotNumber();
        if L_LotNo = '' then
            L_LotNo := GetRequestValue(_RequestValues, 'LotNumber', 'Lot No.');
        L_UomCode := GetRequestValue(_RequestValues, 'UoM', 'UnitofMeasureCode');
        L_PackageNo := GetRequestValue(_RequestValues, 'PackageNumber', 'Package No.');

        L_WhseEntry.SetRange("Item No.", _ItemNo);
        if L_BinCode <> '' then
            L_WhseEntry.SetRange("Bin Code", CopyStr(L_BinCode, 1, MaxStrLen(L_WhseEntry."Bin Code")));
        if L_UomCode <> '' then
            L_WhseEntry.SetRange("Unit of Measure Code", CopyStr(L_UomCode, 1, MaxStrLen(L_WhseEntry."Unit of Measure Code")));
        if L_LotNo <> '' then
            L_WhseEntry.SetRange("Lot No.", CopyStr(L_LotNo, 1, MaxStrLen(L_WhseEntry."Lot No.")));
        if L_PackageNo <> '' then
            L_WhseEntry.SetRange("Package No.", CopyStr(L_PackageNo, 1, MaxStrLen(L_WhseEntry."Package No.")));
        L_WhseEntry.SetFilter("Manufacturer Code", '<>%1', '');
        if L_WhseEntry.FindLast() then
            exit(L_WhseEntry."Manufacturer Code");
        exit('');
    end;

    // Read a request value by its primary key, falling back to an alternate key
    // (a different configuration may name the same field differently).
    local procedure GetRequestValue(var _RequestValues: Record "MOB NS Request Element"; _PrimaryKey: Text; _FallbackKey: Text): Text
    var
        L_Value: Text;
    begin
        L_Value := _RequestValues.GetValue(_PrimaryKey, false);
        if L_Value = '' then
            L_Value := _RequestValues.GetValue(_FallbackKey, false);
        exit(L_Value);
    end;

    // ---------- 2. Stamp the resolved Manufacture Code onto the posted lines ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistrationOnUnplannedCount_OnAfterCreateItemJnlLine', '', true, true)]
    local procedure OnAfterCreateItemJnlLine_UnplannedCount(var _RequestValues: Record "MOB NS Request Element"; _ReservationEntry: Record "Reservation Entry"; var _ItemJnlLine: Record "Item Journal Line")
    var
        L_TaskletCodeunits: Codeunit Tasklet_Codeunits;
        L_MfrCode: Code[100];
    begin
        // Step value is the Manufacturer NAME; store the mapped Code.
        L_MfrCode := L_TaskletCodeunits.GetManufacturerCodeFromName(_ItemJnlLine."Item No.", _RequestValues.GetValue('ManufactureCode', false));
        _ItemJnlLine."Manufacturer Code" := CopyStr(L_MfrCode, 1, MaxStrLen(_ItemJnlLine."Manufacturer Code"));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistrationOnUnplannedCount_OnAfterCreateWhseJnlLine', '', true, true)]
    local procedure OnAfterCreateWhseJnlLine_UnplannedCount(var _RequestValues: Record "MOB NS Request Element"; var _WhseJnlLine: Record "Warehouse Journal Line")
    var
        L_TaskletCodeunits: Codeunit Tasklet_Codeunits;
        L_MfrCode: Code[100];
    begin
        // Step value is the Manufacturer NAME; store the mapped Code.
        L_MfrCode := L_TaskletCodeunits.GetManufacturerCodeFromName(_WhseJnlLine."Item No.", _RequestValues.GetValue('ManufactureCode', false));
        _WhseJnlLine."Manufacturer Code" := CopyStr(L_MfrCode, 1, MaxStrLen(_WhseJnlLine."Manufacturer Code"));
    end;
}
