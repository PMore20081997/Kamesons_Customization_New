// Global namespace (see note in Cod99966) so `extends "Registered Put-away
// Subform"` resolves by name regardless of that page's namespace.

/// <summary>
/// Surfaces the carried-over Pallet No. and its reclassification status on the
/// registered put-away lines, so the operator can see which lines still need the
/// Package No. -> Pallet No. reclassification posted. Both are read-only.
/// </summary>
pageextension 99988 RegPutAwaySubExt extends "Registered Put-away Subform"
{
    layout
    {
        addafter("Bin Code")
        {
            field("Pallet No."; Rec."Pallet No.")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the physical pallet number captured on the put-away line. The stored stock''s Package No. is reclassified to this value.';
            }
            field("Pallet Reclass Posted"; Rec."Pallet Reclass Posted")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies whether the Package No. -> Pallet No. reclassification has been posted for this line.';
            }
        }
    }
}
