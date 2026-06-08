namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

tableextension 99986 WhseActivHeaderExt extends "Warehouse Activity Header"
{
    fields
    {
        field(99972; Priority; Integer)
        {
            Caption = 'Priority';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
    }
}
