// Global namespace (see note in Cod99966) so `extends "Registered Whse.
// Activity Line"` resolves by name regardless of that object's namespace.

/// <summary>
/// Carries the operator-entered Pallet No. onto the registered put-away line,
/// plus the guard flag that records whether the Package-No. reclassification has
/// already been posted for that line.
///
/// "Pallet No." uses the SAME field number (99973) as on "Warehouse Activity
/// Line" so standard BC TransferFields (in codeunit "Whse.-Activity-Register")
/// copies it automatically when the registered line is created — no explicit
/// copy subscriber is needed.
///
/// "Pallet Reclass Posted" is the idempotency / guard flag. Mirrors the standard
/// "don't re-create a put-away once it's created/registered" behaviour: once a
/// line is reclassified it is excluded from re-processing, and a whole-document
/// manual re-run errors out (see codeunit "Pallet Reclass Mgt. NDPP").
/// </summary>
tableextension 99968 RegWhseActLineExt extends "Registered Whse. Activity Line"
{
    fields
    {
        field(99973; "Pallet No."; Code[20])
        {
            Caption = 'Pallet No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(99974; "Pallet Reclass Posted"; Boolean)
        {
            Caption = 'Pallet Reclass Posted';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
