pageextension 99983 WhsePutAwaySubExt extends "Whse. Put-away Subform"
{
    layout
    {
        modify("Zone Code")
        {
            Visible = true;
        }
        movebefore("Bin Code"; "Zone Code")
    }
}
