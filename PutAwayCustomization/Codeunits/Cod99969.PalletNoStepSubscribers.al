namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

/// <summary>
/// Captures the physical Pallet No. on the mobile device during Put-Away and
/// carries it onto the Warehouse Activity Line.
///
/// FLOW
///   1. Device step (id 38) is appended to every Put-Away Place line, directly
///      after Tasklet's "Scan Package No." step (id 37, created by codeunit
///      "MOB Package Management"). Steps are ordered by id, not by subscriber
///      execution order, so 38 always lands immediately after 37.
///   2. The scanned value is written onto the MOB WMS Registration record
///      (field 99951) as the request is parsed. The registration is the only
///      carrier that survives between the scan request and the posting
///      request — SingleInstance state does not.
///   3. At posting, the value is copied from the registration onto the
///      Warehouse Activity Line's "Pallet No." (99973).
///
/// From there the existing chain takes over unchanged: standard TransferFields
/// carries 99973 onto the Registered Whse. Activity Line during registration,
/// and codeunit "Pallet Reclass Mgt. NDPP" reclassifies Package No. -> Pallet
/// No. afterwards.
///
/// Note the step is created on Place lines only. For a bin-mandatory warehouse
/// put-away, Tasklet drives its posting loop from the PLACE line (see
/// SetWhseActLineFilter in codeunit "MOB WMS Activity"), which is also the line
/// the mandatory-Pallet-No. gate in "Pallet Reclass Subs. NDPP" checks.
/// </summary>
codeunit 99969 "Pallet No. Step Subs. NDPP"
{
    // ---- Device step: append after Tasklet's Package No. step (id 37) ----
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Put Away", 'OnGetPutAwayOrderLines_OnAddStepsToWarehouseActivityLine', '', true, true)]
    local procedure OnGetPutAwayOrderLines_OnAddStepsToWarehouseActivityLine(_WhseActivityLine: Record "Warehouse Activity Line"; var _BaseOrderLineElement: Record "MOB NS BaseDataModel Element"; var _Steps: Record "MOB Steps Element")
    begin
        // Invt. Put-away has no Take/Place pair and is not part of the Pallet No.
        // flow — only warehouse put-aways are reclassified downstream.
        if _WhseActivityLine."Activity Type" <> _WhseActivityLine."Activity Type"::"Put-away" then
            exit;

        // Step id 37 is Tasklet's Package No. step; 38 places ours directly after
        // it — steps are ordered by id, not by subscriber execution order.
        // AutoSave=false plus a single Save() at the end mirrors Tasklet's own
        // Package No. step in codeunit "MOB Package Management".
        _Steps.Create_TextStep(38, PalletNoStepNameTok, false);
        _Steps.Set_header(PalletNoHeaderLbl);
        _Steps.Set_label(PalletNoLabelLbl);
        _Steps.Set_helpLabel(PalletNoHelpLbl);
        _Steps.Set_length(20);   // matches Code[20] on "Pallet No."
        _Steps.Set_optional(false);
        _Steps.Save();
    end;

    // ---- Save the scanned value onto the registration ----
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Toolbox", 'OnSaveRegistrationValue', '', true, true)]
    local procedure OnSaveRegistrationValue_PalletNo(_Path: Text; _Value: Text; var _MobileWMSRegistration: Record "MOB WMS Registration"; var _IsHandled: Boolean)
    begin
        if _Path.ToUpper() <> PalletNoStepNameTok.ToUpper() then
            exit;

        if _Value = '' then
            Error(PalletNoMandatoryErr);

        _MobileWMSRegistration."Pallet No." := CopyStr(_Value, 1, MaxStrLen(_MobileWMSRegistration."Pallet No."));
        _IsHandled := true;
    end;

    // ---- Posting: copy from the registration onto the activity line ----
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Put Away", 'OnPostPutAwayOrder_OnHandleRegistrationForWarehouseActivityLine', '', true, true)]
    local procedure OnPostPutAwayOrder_OnHandleRegistrationForWarehouseActivityLine(var _Registration: Record "MOB WMS Registration"; var _WarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        if _Registration."Pallet No." = '' then
            exit;

        // Deliberately no Modify here — Tasklet calls _WhseActLine.Modify(false)
        // immediately after this event returns (see HandleRegistrationForPrimary-
        // WhseActLine in codeunit "MOB WMS Activity"). Modifying here would be
        // redundant and, after a line split, could write to a renumbered record.
        _WarehouseActivityLine."Pallet No." := _Registration."Pallet No.";
    end;

    var
        PalletNoStepNameTok: Label 'PalletNo', Locked = true;
        PalletNoHeaderLbl: Label 'Scan Pallet No.';
        PalletNoLabelLbl: Label 'Pallet No.:';
        PalletNoHelpLbl: Label 'Scan or type the physical pallet number.';
        PalletNoMandatoryErr: Label 'Pallet No. is required before the put-away can be posted.';
}
