namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;

tableextension 99983 Whse_Item_Tracking_Line_Ext extends "Whse. Item Tracking Line"
{
    fields
    {
        field(99971; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = CustomerContent;
        }
        field(99972; "Manufacturer Name"; Text[100])
        {
            Caption = 'Manufacturer Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
