namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Inventory.Item;

// -------------------------------------------------------------------------------------
// Picking Screen on Tasklet Mobile WMS — display-only "Lookup" pattern.
//
//   Lookup page (PickingScreen) -> shows one row per Knapp Order Response line,
//                                  filtered by the entered Document No.
//
// Mirrors the Package Content screen (Cod99953): a read-only Lookup that lists rows
// from a BC table. Data source here is the "Knapp Order Response" table (90506).
//
// Header config key:  'PickingScreenHeader'  (matches application.cfg page "PickingScreen").
// Lookup type:        'PickingScreen'        (matches lookupConfiguration type).
// -------------------------------------------------------------------------------------

codeunit 99954 "Picking Screen Tasklet"
{
    Access = Public;

    // ---------- 1. Header configuration: Tote ID ------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Reference Data", 'OnGetReferenceData_OnAddHeaderConfigurations', '', true, true)]
    local procedure OnAddHeaderConfigurations_PickingScreen(var _HeaderFields: Record "MOB HeaderField Element")
    begin
        _HeaderFields.InitConfigurationKey('PickingScreenHeader');

        // Tote ID — scan or type; filters the listed lines by Load Unit (Tote ID).
        _HeaderFields.Create_TextField(1, 'ToteID', 'Tote ID:');
        _HeaderFields.Set_optional(true);
    end;

    // ---------- 2. Lookup: list Knapp Order Response lines for the entered Document No. ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Lookup", 'OnLookupOnCustomLookupType', '', true, true)]
    local procedure OnLookupOnCustomLookupType_PickingScreen(_MessageId: Guid; _LookupType: Text; var _RequestValues: Record "MOB NS Request Element"; var _LookupResponseElement: Record "MOB NS WhseInquery Element"; var _XmlResultDoc: XmlDocument; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        L_Item: Record Item;
        KnappOrderResponse: Record "Knapp Order Response";
        ToteIDFilter: Text;
    begin
        if _IsHandled then
            exit;
        if _LookupType <> 'PickingScreen' then
            exit;

        ToteIDFilter := _RequestValues.GetValue('ToteID');

        // Blank Tote ID -> no filter -> show all lines.
        if ToteIDFilter <> '' then
            KnappOrderResponse.SetFilter("Load Unit", ToteIDFilter);
        KnappOrderResponse.SetCurrentKey("Document No.", "Line No.");

        if KnappOrderResponse.FindSet() then
            repeat
                _LookupResponseElement.Create();

                // Line 1 (headline): Item No.
                _LookupResponseElement.Set_DisplayLine1(KnappOrderResponse."Load Unit");
                // Line 2: Description.
                _LookupResponseElement.Set_DisplayLine2(KnappOrderResponse."Item No.");
                If KnappOrderResponse."Item No." <> '' then
                    if L_Item.Get(KnappOrderResponse."Item No.") then
                        _LookupResponseElement.Set_DisplayLine3(L_Item.Description);
                // Line 3: Document No. / Line No.
                _LookupResponseElement.Set_DisplayLine4('Doc: ' + KnappOrderResponse."Document No." +
                    '  Line: ' + Format(KnappOrderResponse."Line No."));

                // Right-hand column: Quantity (and UoM in the registrations list slot).
                _LookupResponseElement.Set_Quantity(Format(KnappOrderResponse.Quantity));
                _LookupResponseElement.Set_ExtraInfo1(KnappOrderResponse."Unit of Measure");
            until KnappOrderResponse.Next() = 0;

        _IsHandled := true;
    end;
}
