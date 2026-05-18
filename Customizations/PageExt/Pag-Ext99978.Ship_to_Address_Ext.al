namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Customer;

pageextension 99978 Ship_to_Address_Ext extends "Ship-to Address"
{
    layout
    {
        addlast(General)
        {

            field(Dispensary; Rec.Dispensary)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Dispensary field.', Comment = '%';
            }
            field("Retail "; Rec."Retail ")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Retail field.', Comment = '%';
            }
        }
    }
}
