pageextension 99983 WhsePutAwaySubExt extends "Whse. Put-away Subform"
{
    layout
    {
        addafter("Lot No.")
        {
            field("Manufacturer Code"; Rec."Manufacturer Code")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Manufacturer Code field.', Comment = '%';
            }
            field("Manufacturer Name"; Rec."Manufacturer Name")
            {
                ApplicationArea = All;
                Caption = 'Manufacturer Name';
                Editable = false;
                ToolTip = 'Specifies the name of the manufacturer for the Manufacturer Code.';
            }
            field("Pallet No."; Rec."Pallet No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the physical pallet number for this put-away line. On registration the stored stock''s Package No. is automatically reclassified to this value. Mandatory on Place lines.';
                // This subform only shows Put-away lines, so Activity-Type gating
                // is automatic — only restrict editing/mandatory to Place lines.
                Editable = Rec."Action Type" = Rec."Action Type"::Place;
                ShowMandatory = Rec."Action Type" = Rec."Action Type"::Place;
            }
        }
        modify("Zone Code")
        {
            Visible = true;
        }
        movebefore("Bin Code"; "Zone Code")
    }
}
