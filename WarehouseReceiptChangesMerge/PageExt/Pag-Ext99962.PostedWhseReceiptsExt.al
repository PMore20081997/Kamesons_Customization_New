namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.History;

pageextension 99962 PostedWhseReceiptsExt extends "Posted Whse. Receipt List"
{
    layout
    {
        addlast(Control1)
        {
            field("Transportation Arranged By"; Rec."Transportation Arranged By")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Preferred Delivery Date"; Rec."Preferred Delivery Date")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Expected Delivery Date"; Rec."Expected Delivery Date")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Expected Delivery Time"; Rec."Expected Delivery Time")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Expected Pallets"; Rec."Expected Pallets")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Expected Lifts"; Rec."Expected Lifts")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Expected Loose Boxes"; Rec."Expected Loose Boxes")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Received Lifts"; Rec."Received Lifts")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Received Loose Boxes"; Rec."Received Loose Boxes")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("No. of Items"; Rec."No. of Items")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Comments"; Rec."Comments")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Receiving Status"; Rec."Receiving Status")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Received Date"; Rec."Received Date")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Received Time"; Rec."Received Time")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Received Pallets"; Rec."Received Pallets")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Received Pallets field.', Comment = '%';
                Visible = false;
            }
            field("Shipping Carrier"; Rec."Shipping Carrier")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
            field("Delivery Term"; Rec."Delivery Term")
            {
                ApplicationArea = Warehouse;
                Visible = false;
            }
        }
    }

}
