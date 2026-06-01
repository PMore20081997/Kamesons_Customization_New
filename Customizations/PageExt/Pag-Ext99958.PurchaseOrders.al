namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;

pageextension 99958 "Purchase Orders" extends "Purchase Order List"
{
    layout
    {
        addlast(Control1)
        {

            field("Whse. Receipt Error"; Rec."Whse. Receipt Error")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Whse. Receipt Error field.', Comment = '%';
            }
        }
        addafter(Status)
        {

            field("Expected Pallets"; Rec."Expected Pallets")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Expected Pallets field.', Comment = '%';
            }
            field("Received Pallets"; Rec."Received Pallets")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Received Pallets field.', Comment = '%';
            }
        }
    }
}
