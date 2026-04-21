namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

tableextension 99974 Item_Ext extends Item
{
    fields
    {
        field(99971; "BULK"; Boolean)
        {
            Caption = 'BULK';
            DataClassification = ToBeClassified;
        }
    }
}
