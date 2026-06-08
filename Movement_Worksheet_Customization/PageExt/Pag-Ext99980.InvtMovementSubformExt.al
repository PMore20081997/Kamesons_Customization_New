namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

pageextension 99978 InvtMovementSubformExt extends "Invt. Movement Subform"
{
    layout
    {
        addafter("Item No.")
        {
            field(Priority; Rec.Priority)
            {
                ApplicationArea = All;
                Caption = 'Priority';
                ToolTip = 'Specifies the priority for this movement line. Transferred automatically from the Movement Worksheet.';
                Editable = false;
            }
        }
    }
}
