namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.History;

tableextension 99951 "Posted_Whse._Receipt_Line_Ext" extends "Posted Whse. Receipt Line"
{
    fields
    {
        field(99971; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = CustomerContent;
        }
    }
}
