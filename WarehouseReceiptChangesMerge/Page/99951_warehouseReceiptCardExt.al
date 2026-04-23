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
                field("Confirmed Delivery Date"; Rec."Confirmed Delivery Date")
                {
                    ApplicationArea = Warehouse;
                }
                field("Confirmed Delivery Time"; Rec."Confirmed Delivery Time")
                {
                    ApplicationArea = Warehouse;
                }
                field("Confirmed Pallets"; Rec."Confirmed Pallets")
                {
                    ApplicationArea = Warehouse;
                }
                field("Confirmed Lifts"; Rec."Confirmed Lifts")
                {
                    ApplicationArea = Warehouse;
                }
                field("Confirmed Loose Boxes"; Rec."Confirmed Loose Boxes")
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