namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;

tableextension 99983 Whse_Item_Tracking_Line_Ext extends "Whse. Item Tracking Line"
{
    fields
    {
        field(99971; "Manufacture Code"; Code[100])
        {
            Caption = 'Manufacture Code';
            DataClassification = ToBeClassified;
        }
    }
}
