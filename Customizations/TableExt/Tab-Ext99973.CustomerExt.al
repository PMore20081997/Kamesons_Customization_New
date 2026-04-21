namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Customer;

tableextension 99973 CustomerExt extends Customer
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
