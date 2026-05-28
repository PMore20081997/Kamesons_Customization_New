namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;

pageextension 99957 Sales_Order_Ext extends "Sales Order"
{
    layout
    {
        addlast("Shipping and Billing")
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
        addlast(factboxes)
        {
            part(ReceiveBinContentDetails; "Bin Content Details")
            {
                SubPageLink = "Item No." = field("No.");
                ApplicationArea = all;
                Caption = 'Bin Content Details';
                Provider = SalesLines;
            }
            part(ItemManufacturerFactbox; "Item Manufacturer Factbox")
            {
                SubPageLink = "Item No" = field("No.");
                ApplicationArea = all;
                Caption = 'Item Manufacturer Factbox';
                Provider = SalesLines;
            }
        }
    }
}
