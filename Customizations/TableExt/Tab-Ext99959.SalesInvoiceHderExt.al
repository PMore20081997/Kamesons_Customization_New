namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.History;

tableextension 99959 SalesInvoiceHderExt extends "Sales Invoice Header"
{
    fields
    {
        field(99950; "Dispensary"; Boolean)
        {
            Caption = 'Dispensary';
            DataClassification = ToBeClassified;
        }
        field(99951; "Retail "; Boolean)
        {
            Caption = 'Retail';
            DataClassification = ToBeClassified;
        }
    }
}
