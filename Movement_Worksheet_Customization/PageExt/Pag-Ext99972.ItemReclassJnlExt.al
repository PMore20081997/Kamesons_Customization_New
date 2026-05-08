pageextension 99972 ItemReclassJnlExt extends "Item Reclass. Journal"
{
    layout
    {
        addafter("Item No.")
        {

            field("Manufacturer Code"; Rec."Manufacturer Code")
            {
                ApplicationArea = All;
                Caption = 'Manufacturer Code';
                ToolTip = 'Specifies the value of the Manufacturer Code field.';
            }
        }
    }

}
