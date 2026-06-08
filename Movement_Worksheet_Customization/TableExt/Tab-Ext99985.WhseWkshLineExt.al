namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Worksheet;

tableextension 99985 WhseWkshLineExt extends "Whse. Worksheet Line"
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
