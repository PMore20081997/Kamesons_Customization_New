namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

pageextension 99977 InventoryMovementExt extends "Inventory Movement"
{
    layout
    {
        addlast(General)
        {
            field(Priority; Rec.Priority)
            {
                ApplicationArea = All;
                Caption = 'Priority';
                ToolTip = 'Specifies the priority of this inventory movement. Transferred automatically from the Movement Worksheet when the movement is created.';
            }
        }
    }
}
