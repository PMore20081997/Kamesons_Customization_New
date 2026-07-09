namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;
using Microsoft.Inventory.Journal;
using Microsoft.Warehouse.Journal;

// -------------------------------------------------------------------------------------
// Planned Count on Tasklet Mobile WMS — Manufacture Code (Manufacturer Name) step.
//
// Mirrors the Unplanned Count logic (Cod99955) for the PLANNED Count flow
// (menu "Count" / service "Count", codeunit "MOB WMS Count"), which counts both
// Item Journal ("I-") and Warehouse Journal ("W-") batches.
//
// In planned Count the Package No. step is an AL-added tracking step (not part of the
// standard workflow), so it is present in the _Steps record of
// OnGetCountOrderLines_OnAddStepsToAnyLine. We catch it there by name and attach the
// online validation directly to it (Set_onlineValidation), so the validation fires
// when the operator confirms Package No. — no hidden trigger, no cfg tweak.
//
// We also add one visible step:
//   * ManufactureCode (id 39) — display shows the Manufacturer NAME, shown right
//     after Package. The Package No. validation pushes the resolved value onto it
//     (id 39 is higher than the Package step id, a valid forward-write target).
//
// On Package No. confirm, the PackageNumberValidation online validation reads
// Item/Bin/UoM (from the line) + Lot/Package (collected step values), filters
// Warehouse Entry, maps Manufacturer Code -> Name, and writes the Name onto the
// ManufactureCode step via the documented 'stepUpdates' response.
//
// At post, the Manufacturer Code is already on the MOB WMS Registration (the global
// OnSaveRegistrationValue_ManufactureCode hook in Cod99951 maps the picked NAME to a
// Code for any step named 'ManufactureCode'); we stamp it onto the journal line.
//
// The Warehouse Entry lookup / Name-Code mapping helpers live in Cod99951/Cod99955
// where possible; the shared Name<-Code mapping is reused from Cod99951.
// -------------------------------------------------------------------------------------

codeunit 99957 "Planned Count Manufacture"
{
    Access = Public;

    // ---------- Register the online-validation document type ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Setup Doc. Types", 'OnAfterCreateDefaultDocumentTypes', '', true, true)]
    local procedure RegisterPlannedCountDocTypes()
    var
        L_MobWmsSetupDocTypes: Codeunit "MOB WMS Setup Doc. Types";
    begin
        L_MobWmsSetupDocTypes.CreateDocumentType('PackageNumberValidation', '', Codeunit::"MOB WMS Whse. Inquiry");
    end;

    // ---------- Attach validation to Package No. + add the Manufacture Code step ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Count", 'OnGetCountOrderLines_OnAddStepsToAnyLine', '', true, true)]
    local procedure OnAddStepsToAnyLine_PlannedCount(_RecRef: RecordRef; var _BaseOrderLineElement: Record "MOB NS BaseDataModel Element"; var _Steps: Record "MOB Steps Element")
    begin
        // Attach the online validation to the existing Package No. step FIRST, while
        // _Steps is in its incoming state. Direct filter+Save on _Steps is required
        // (a copied record's Save() does not persist) — proven by the request firing.
        _Steps.Reset();
        _Steps.SetRange(name, 'PackageNumber');
        if _Steps.FindFirst() then begin
            _Steps.Set_onlineValidation('PackageNumberValidation', true);
            _Steps.Save();
        end;

        // Create the Manufacture Code step (id 39) LAST. Clear the filter set above so
        // Create_TextStep operates on the full step set, and do it after the Package
        // filtering so the cursor change can't drop our newly created step. This step
        // is the write target the Package No. validation pushes the Manufacturer NAME
        // onto (id 39 is higher than the Package step id — a valid forward write).
        _Steps.Reset();
        _Steps.Create_TextStep(39, 'ManufactureCode');
        _Steps.Set_header('Manufacturer Name');
        _Steps.Set_label('Manufacturer Name: ');
        _Steps.Set_helpLabel('Manufacturer for the counted stock');
        _Steps.Set_optional(true);
    end;

    // ---------- Online validation: resolve the manufacturer on Package No. ----------

    // Fires when the operator confirms the Package No. step. The planned Count request
    // does NOT carry an Item node — it identifies the line by OrderBackendID (prefixed
    // I-/W-) + LineNumber. Resolve Item + Bin + UoM from the count journal line, read
    // Lot/Package from the request, filter Warehouse Entry, map the Manufacturer Code
    // to its Name, and write the Name onto the ManufactureCode step (id 39) via
    // 'stepUpdates'.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Whse. Inquiry", 'OnWhseInquiryOnCustomDocumentType', '', true, true)]
    local procedure OnWhseInquiry_PackageNumberValidation(_DocumentType: Text; var _RequestValues: Record "MOB NS Request Element"; var _ResponseElement: Record "MOB NS Resp Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
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
        if _DocumentType <> 'PackageNumberValidation' then
            exit;

        // Item / Bin / UoM come from the count journal line (identified by the request's
        // OrderBackendID + LineNumber); Lot / Package are collected step values.
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
            _ResponseElement.SetValue('step/@name', 'ManufactureCode');
            _ResponseElement.SetValue('step/@value', L_MfrName);
            _ResponseElement.SetValue('step/@interactionPermission', Format(Enum::"MOB ValueInteractionPermission"::AllowEdit));
        end;

        _IsHandled := true;
    end;

    // Resolve Item + Bin + UoM from the count journal line the request refers to.
    // OrderBackendID is prefixed 'I-' (Item Journal) or 'W-' (Warehouse Journal);
    // the batch name is the backendId without the 2-char prefix.
    local procedure ResolveLineStock(var _RequestValues: Record "MOB NS Request Element"; var _ItemNo: Code[20]; var _BinCode: Code[20]; var _UomCode: Code[10])
    var
        L_MobSetup: Record "MOB Setup";
        L_ItemJnlLine: Record "Item Journal Line";
        L_WhseJnlLine: Record "Warehouse Journal Line";
        L_BackendID: Text;
        L_LineNoText: Text;
        L_BatchName: Code[10];
        L_LineNo: Integer;
    begin
        // This validation request carries the line identity as plain 'backendId' /
        // 'lineNumber' nodes (confirmed in the Mobile Document Queue), not via the
        // OrderBackendID/LineNumber accessors — so read the node names, with the
        // accessors kept as a fallback for other flows.
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

        L_MobSetup.Get();
        L_BatchName := CopyStr(CopyStr(L_BackendID, 3), 1, MaxStrLen(L_BatchName));

        case CopyStr(L_BackendID, 1, 2) of
            'I-':
                begin
                    L_ItemJnlLine.SetRange("Journal Template Name", L_MobSetup."Inventory Jnl Template");
                    L_ItemJnlLine.SetRange("Journal Batch Name", L_BatchName);
                    L_ItemJnlLine.SetRange("Line No.", L_LineNo);
                    if L_ItemJnlLine.FindFirst() then begin
                        _ItemNo := L_ItemJnlLine."Item No.";
                        _BinCode := L_ItemJnlLine."Bin Code";
                        _UomCode := L_ItemJnlLine."Unit of Measure Code";
                    end;
                end;
            'W-':
                begin
                    L_WhseJnlLine.SetRange("Journal Template Name", L_MobSetup."Whse Inventory Jnl Template");
                    L_WhseJnlLine.SetRange("Journal Batch Name", L_BatchName);
                    L_WhseJnlLine.SetRange("Line No.", L_LineNo);
                    if L_WhseJnlLine.FindFirst() then begin
                        _ItemNo := L_WhseJnlLine."Item No.";
                        _BinCode := L_WhseJnlLine."Bin Code";
                        _UomCode := L_WhseJnlLine."Unit of Measure Code";
                    end;
                end;
        end;
    end;

    // Manufacturer Code from the Warehouse Entries for the counted stock: Item + Bin +
    // UoM (from the line) + Lot + Package (collected). Each filter is applied only when
    // the value is present, so it narrows as far as available. Last matching entry with
    // a non-blank Manufacturer Code wins (mirrors Cod99955 / LookupManufacturerCodeByLot).
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

    // ---------- Stamp the resolved Manufacture Code onto the posted journal lines ----------

    // The global OnSaveRegistrationValue_ManufactureCode hook (Cod99951) has already
    // mapped the picked Manufacturer NAME to a Code on the registration, for any step
    // named 'ManufactureCode'. Copy it onto the journal line being counted.

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Count", 'OnPostCountOrder_OnHandleRegistrationForItemJournalLine', '', true, true)]
    local procedure OnHandleRegistration_ItemJnlLine_PlannedCount(var _Registration: Record "MOB WMS Registration"; var _ItemJnlLine: Record "Item Journal Line")
    begin
        if _Registration."Manufacturer Code" = '' then
            exit;
        _ItemJnlLine."Manufacturer Code" := CopyStr(_Registration."Manufacturer Code", 1, MaxStrLen(_ItemJnlLine."Manufacturer Code"));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Count", 'OnPostCountOrder_OnHandleRegistrationForWarehouseJournalLine', '', true, true)]
    local procedure OnHandleRegistration_WhseJnlLine_PlannedCount(var _Registration: Record "MOB WMS Registration"; var _WhseJnlLine: Record "Warehouse Journal Line")
    begin
        if _Registration."Manufacturer Code" = '' then
            exit;
        _WhseJnlLine."Manufacturer Code" := CopyStr(_Registration."Manufacturer Code", 1, MaxStrLen(_WhseJnlLine."Manufacturer Code"));
    end;
}
