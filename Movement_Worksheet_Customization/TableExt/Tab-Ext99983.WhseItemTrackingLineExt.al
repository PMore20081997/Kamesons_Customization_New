namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;

tableextension 99983 Whse_Item_Tracking_Line_Ext extends "Whse. Item Tracking Line"
{
    fields
    {
        field(99971; "Manufacturer Code"; Code[10])
        {
            Caption = 'Manufacturer Code';
            DataClassification = CustomerContent;
        }
    }
}
