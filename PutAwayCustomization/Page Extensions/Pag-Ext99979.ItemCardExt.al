namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

pageextension 99979 Item_Card_Ext extends "Item Card"
{
    layout
    {
        addlast(Item)
        {
            field(BULK; Rec.BULK)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the BULK field.', Comment = '%';
            }
        }
    }
}
