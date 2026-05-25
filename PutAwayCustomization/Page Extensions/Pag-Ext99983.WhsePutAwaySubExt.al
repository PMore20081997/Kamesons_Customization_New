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
        }
        modify("Zone Code")
        {
            Visible = true;
        }
        movebefore("Bin Code"; "Zone Code")
    }
}
