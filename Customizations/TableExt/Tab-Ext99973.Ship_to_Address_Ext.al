namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Customer;

tableextension 99973 Ship_to_Address_Ext extends "Ship-to Address"
{
    fields
    {
        field(99971; "Dispensary"; Boolean)
        {
            Caption = 'Dispensary';
            DataClassification = ToBeClassified;
        }
        field(99972; "Retail "; Boolean)
        {
            Caption = 'Retail';
            DataClassification = ToBeClassified;
        }
    }
}
