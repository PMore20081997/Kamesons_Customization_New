namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

tableextension 99984 WhseActLineExt extends "Warehouse Activity Line"
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
