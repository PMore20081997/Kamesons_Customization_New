// Global namespace (see note in Cod99966) so the "Registered Whse. Activity"
// types in the event signatures resolve by name without a version-specific using.

/// <summary>
/// US xxxxx — Event subscribers wiring the Pallet-No. reclassification into
/// warehouse Put-Away registration. Contains no business logic beyond the
/// mandatory-field gate; the posting itself lives in "Pallet Reclass Mgt. NDPP".
///
/// Stateless by design (no SingleInstance): the "Pallet No." value is propagated
/// onto the registered line by standard BC TransferFields (same field No. 99973
/// on both tables), and the auto trigger locates the freshly-created registered
/// header directly via its "Whse. Activity No." link to the source activity —
/// so no state needs to be carried between events.
/// </summary>
codeunit 99967 "Pallet Reclass Subs. NDPP"
{
    // ---- Mandatory gate: every Put-Away Place line must carry a Pallet No. ----
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Activity-Register", OnBeforeRegisterWhseActivityLines, '', false, false)]
    local procedure OnBeforeRegisterWhseActivityLines(var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        CheckLine: Record "Warehouse Activity Line";
    begin
        CheckLine.CopyFilters(WarehouseActivityLine);
        if WarehouseActivityLine."No." <> '' then
            CheckLine.SetRange("No.", WarehouseActivityLine."No.");
        CheckLine.SetRange("Activity Type", CheckLine."Activity Type"::"Put-away");
        CheckLine.SetRange("Action Type", CheckLine."Action Type"::Place);
        CheckLine.SetRange("Pallet No.", '');
        if CheckLine.FindFirst() then
            Error(PalletNoMissingErr, CheckLine."Line No.", CheckLine."Item No.");
    end;

    // ---- Auto trigger: reclassify Package No. -> Pallet No. after registration. ----
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Activity-Register", OnAfterRegisterWhseActivity, '', false, false)]
    local procedure OnAfterRegisterWhseActivity(var WarehouseActivityHeader: Record "Warehouse Activity Header"; SuppressCommit: Boolean)
    var
        RegHeader: Record "Registered Whse. Activity Hdr.";
        PalletReclassMgt: Codeunit "Pallet Reclass Mgt. NDPP";
    begin
        if WarehouseActivityHeader.Type <> WarehouseActivityHeader.Type::"Put-away" then
            exit;

        // Find the registered header just created from this activity. Registration
        // stamps the source activity "No." onto "Whse. Activity No." of the
        // registered header; FindLast picks the one created in this transaction.
        RegHeader.SetRange(Type, RegHeader.Type::"Put-away");
        RegHeader.SetRange("Whse. Activity No.", WarehouseActivityHeader."No.");
        if not RegHeader.FindLast() then
            exit;

        // Run trapped: a posting failure leaves the registration intact and the
        // lines flagged for manual posting (see Cod99966). The empty THEN
        // deliberately swallows the boolean result.
        if PalletReclassMgt.Run(RegHeader) then;
    end;

    var
        PalletNoMissingErr: Label 'Pallet No. is required on Put-away Place line %1 (item %2) before the put-away can be registered.', Comment = '%1 = Line No., %2 = Item No.';
}
