namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;

pageextension 99957 Sales_Order_Ext extends "Sales Order"
{
    layout
    {
        addlast(factboxes)
        {
            part(ReceiveBinContentDetails; "Receive Bin Content Details")
            {
                SubPageLink = "Item No." = field("No.");
                ApplicationArea = all;
                Caption = 'Receive Bin Content Details';
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
