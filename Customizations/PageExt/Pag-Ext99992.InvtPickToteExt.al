namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

pageextension 99987 InvtPickToteExt extends "Inventory Pick"
{
    layout
    {
        addafter("External Document No.")
        {
            field("Tote No. NDPP"; Rec."Tote No. NDPP")
            {
                ApplicationArea = Warehouse;
                Caption = 'Tote No.';
                Editable = false;
                ToolTip = 'Specifies the Knapp tote number assigned to this inventory pick.';
            }
        }
    }
}
