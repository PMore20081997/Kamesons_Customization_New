pageextension 99951 "Warehouse Receipt Card Ext" extends "Warehouse Receipt"
{
    layout
    {
        addafter(WhseReceiptLines)
        {
            group(Transportation)
            {
                Caption = 'Transportation';
                field("Transportation Arranged By"; Rec."Transportation Arranged By")
                {
                    ApplicationArea = Warehouse;
                }
                field("Preferred Delivery Date"; Rec."Preferred Delivery Date")
                {
                    ApplicationArea = Warehouse;
                }
                field("Expected Delivery Date"; Rec."Expected Delivery Date")
                {
                    ApplicationArea = Warehouse;
                }
                field("Expected Delivery Time"; Rec."Expected Delivery Time")
                {
                    ApplicationArea = Warehouse;
                }
                field("Expected Pallets"; Rec."Expected Pallets")
                {
                    ApplicationArea = Warehouse;
                }
                field("Expected Lifts"; Rec."Expected Lifts")
                {
                    ApplicationArea = Warehouse;
                }
                field("Expected Loose Boxes"; Rec."Expected Loose Boxes")
                {
                    ApplicationArea = Warehouse;
                }
                field("Received Lifts"; Rec."Received Lifts")
                {
                    ApplicationArea = Warehouse;
                }
                field("Received Loose Boxes"; Rec."Received Loose Boxes")
                {
                    ApplicationArea = Warehouse;
                }
                field("Received Pallets"; Rec."Received Pallets")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Received Pallets field.', Comment = '%';
                }
                field("No. of Items"; Rec."No. of Items")
                {
                    ApplicationArea = Warehouse;
                }
                field("Comments"; Rec."Comments")
                {
                    ApplicationArea = Warehouse;
                }
                field("Receiving Status"; Rec."Receiving Status")
                {
                    ApplicationArea = Warehouse;
                }
                field("Received Date"; Rec."Received Date")
                {
                    ApplicationArea = Warehouse;
                }
                field("Received Time"; Rec."Received Time")
                {
                    ApplicationArea = Warehouse;
                }
                field("Shipping Carrier"; Rec."Shipping Carrier")
                {
                    ApplicationArea = Warehouse;
                }
                field("Delivery Term"; Rec."Delivery Term")
                {
                    ApplicationArea = Warehouse;
                }



            }

        }
    }
}