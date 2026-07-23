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
            field("Manufacturer Name"; Rec."Manufacturer Name")
            {
                ApplicationArea = All;
                Caption = 'Manufacturer Name';
                Editable = false;
                ToolTip = 'Specifies the name of the manufacturer for the Manufacturer Code.';
            }
        }
    }

}
