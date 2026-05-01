namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Document;

pageextension 99955 WhseReceiptsExt extends "Warehouse Receipts"
{
    layout
    {
        addafter("No.")
        {
            
            field("Confirmed Delivery Date"; Rec."Confirmed Delivery Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Confirmed Delivery Date field.', Comment = '%';
            }
            field("Shipping Carrier"; Rec."Shipping Carrier")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Shipping Carrier field.', Comment = '%';
            }
        }
    }
}
