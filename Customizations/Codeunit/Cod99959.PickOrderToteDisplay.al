namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

// -------------------------------------------------------------------------------------
// Pick Orders list (Tasklet Mobile WMS) — Tote No. on the card + scan-to-open-pick.
//
// 1) DISPLAY
//    The Pick Orders list rows for Invt. Pick / Pick documents are built by
//    "MOB WMS Activity".SetFromWhseActivityHeader, which fills all 5 display lines:
//
//      Line1: Source Document + Source No.   e.g. "Sales Order WEB00105"
//      Line2: Customer / Vendor / Location
//      Line3: Location name
//      Line4: "Invt. Pick: IPI000050"
//      Line5: "Shipment Date: 7/9/2026"
//
//    There is no free display slot, so we append the Tote No. into Line1 (below the
//    order number) using the CRLF-in-cell technique used elsewhere in the Tasklet source.
//
// 2) SCAN A TOTE -> OPEN ITS PICK
//    A custom "Tote ID" text field is added to the Pick Orders list header
//    (InitConfigurationKey_PickOrderFilters). When the user scans/types a tote there,
//    OnGetPickOrders_OnSetFilterWarehouseActivity resolves it against
//    Warehouse Activity Header."Tote No. NDPP" and narrows the list to that pick.
//
//    We use a custom field (not the built-in 'ScannedValue') on purpose: the base
//    'ScannedValue' path runs "Scanned Value Mgt".SetFilterForWhseActivity() after the
//    event and would overwrite our filter (a tote matches no Activity No. -> empty list).
//    That codeunit has no extension point, so a separate filter field is the reliable hook.
//
//    Tote source: Warehouse Activity Header."Tote No. NDPP" (Tab-Ext99990) — 1 tote = 1 pick.
// -------------------------------------------------------------------------------------

codeunit 99959 "Pick Order Tote Display"
{
    Access = Public;

    // ---------- 1. Header configuration: add a "Tote ID" filter to the Pick Orders list ----------

    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Reference Data", 'OnGetReferenceData_OnAddHeaderConfigurations', '', true, true)]
    local procedure OnAddHeaderConfigurations_AddToteIdToPickOrders(var _HeaderFields: Record "MOB HeaderField Element")
    begin
        // Extend the standard Pick Orders header (same key the base uses for Location/AssignedUser).
        _HeaderFields.InitConfigurationKey_PickOrderFilters();

        // Tote ID — scan or type; narrows the pick list to the pick holding that tote.
        _HeaderFields.Create_TextField(30, 'ToteID', 'Tote ID:');
        _HeaderFields.Set_optional(true);
    end;

    // ---------- 2. Resolve the scanned Tote ID -> the pick that holds it ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Pick", 'OnGetPickOrders_OnSetFilterWarehouseActivity', '', true, true)]
    local procedure OnSetFilterWhseActivity_ApplyToteFilter(_HeaderFilter: Record "MOB NS Request Element"; var _WhseActHeader: Record "Warehouse Activity Header"; var _WhseActLine: Record "Warehouse Activity Line"; var _IsHandled: Boolean)
    var
        L_ToteId: Code[20];
    begin
        // The event fires once per header-filter row (plus once with a blank row).
        // React only on our custom 'ToteID' row with a non-blank value.
        if _HeaderFilter.Name <> 'ToteID' then
            exit;

        L_ToteId := CopyStr(_HeaderFilter."Value", 1, MaxStrLen(L_ToteId));
        if L_ToteId = '' then
            exit;

        // Narrow the (Pick / Invt. Pick) list to the header(s) carrying this tote.
        // Type / Location filters already set by the base remain in effect.
        _WhseActHeader.SetRange("Tote No. NDPP", L_ToteId);

        // Handled -> skip the base 'case' for this row (there is no base handler for 'ToteID' anyway).
        _IsHandled := true;
    end;*/

    // ---------- 3. Show the Tote No. on each Pick Orders card ----------

    // Fires once per Warehouse Activity (Pick / Invt. Pick) header after the base
    // display lines have been set. Append the Tote No. under the Sales Order line.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Pick", 'OnGetPickOrders_OnAfterSetFromWarehouseActivityHeader', '', true, true)]
    local procedure OnAfterSetFromWhseActHeader_AppendTote(_WhseActHeader: Record "Warehouse Activity Header"; var _BaseOrderElement: Record "MOB NS BaseDataModel Element")
    var
        L_MobToolbox: Codeunit "MOB Toolbox";
        L_ToteText: Text;
    begin
        // Show '-' as a placeholder when no Tote has been assigned yet.
        if _WhseActHeader."Tote No. NDPP" <> '' then
            L_ToteText := 'Tote: ' + _WhseActHeader."Tote No. NDPP"
        else
            L_ToteText := 'Tote: ';

        // Append below the existing "Sales Order ..." text on Display Line 1.
        _BaseOrderElement.Set_DisplayLine1(
            _BaseOrderElement.Get_DisplayLine1() + L_MobToolbox.CRLFSeparator() + L_ToteText);
    end;
}
