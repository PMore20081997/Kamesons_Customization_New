namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.History;

pageextension 99953 PostPurchRcptCardExt extends "Posted Purchase Receipt"
{
    layout
    {
        addafter(PurchReceiptLines)
        {
            group(Transportation)
            {
                Caption = 'Transportation';
                field("Transportation Arranged By"; Rec."Transportation Arranged By")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Preferred Delivery Date"; Rec."Preferred Delivery Date")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Expected Delivery Date"; Rec."Expected Delivery Date")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Expected Delivery Time"; Rec."Expected Delivery Time")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Expected Pallets"; Rec."Expected Pallets")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Expected Lifts"; Rec."Expected Lifts")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Expected Loose Boxes"; Rec."Expected Loose Boxes")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Received Lifts"; Rec."Received Lifts")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Received Loose Boxes"; Rec."Received Loose Boxes")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("No. of Items"; Rec."No. of Items")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Comments"; Rec."Comments")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Receiving Status"; Rec."Receiving Status")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Received Date"; Rec."Received Date")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Received Time"; Rec."Received Time")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Received Pallets"; Rec."Received Pallets")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Received Pallets field.', Comment = '%';
                    Editable = false;
                }
                field("Shipping Carrier"; Rec."Shipping Carrier")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }
                field("Delivery Term"; Rec."Delivery Term")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                }



            }

        }
    }
}
