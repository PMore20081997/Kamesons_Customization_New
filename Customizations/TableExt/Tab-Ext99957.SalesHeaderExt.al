namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;

tableextension 99957 SalesHeaderExt extends "Sales Header"
{
    fields
    {
        field(99950; "Dispensary"; Boolean)
        {
            Caption = 'Dispensary';
            DataClassification = CustomerContent;
        }
        field(99951; "Retail "; Boolean)
        {
            Caption = 'Retail';
            DataClassification = CustomerContent;
        }
        field(99972; "Special Order"; Boolean)
        {
            Caption = 'Special Order';
            DataClassification = CustomerContent;
        }
    }
}
