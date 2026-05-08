pageextension 99975 ItemManufacturerExt extends "Item Manufacturer Page"
{
    layout
    {
        addafter("Manufacturer Region")
        {

            field("Qty per Tote"; Rec."Qty per Tote")
            {
                ApplicationArea = All;
                Caption = 'Qty per Tote';
                ToolTip = 'Specifies the value of the Max. Qty per Tote field.';
            }
        }
    }
}
