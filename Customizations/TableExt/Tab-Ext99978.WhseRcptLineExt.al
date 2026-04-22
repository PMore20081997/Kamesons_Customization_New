namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Document;

tableextension 99978 WhseRcptLineExt extends "Warehouse Receipt Line"
{
    fields
    {
        field(99971; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = ToBeClassified;
        }
    }
}
