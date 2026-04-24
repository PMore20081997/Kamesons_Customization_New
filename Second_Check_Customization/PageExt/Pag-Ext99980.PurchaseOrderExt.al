namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;

pageextension 99980 Purchase_Order_Ext extends "Purchase Order"
{
    layout
    {
        addlast(General)
        {

            field("Second Check"; Rec."Second Check")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Second Check field.', Comment = '%';
                Editable = MakeEditable;
            }
            field("Second Check User"; Rec."Second Check User")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Second Check User field.', Comment = '%';
                Editable = false;
            }
            field("Second Check Date"; Rec."Second Check Date & Time")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Second Check Date field.', Comment = '%';
                Editable = false;
            }
        }
        addfirst(FactBoxes)
        {
            part("Last 10 Released POs"; "Purchase Order History")
            {
                ApplicationArea = All;

                Provider = PurchLines;

                SubPageLink = "No." = FIELD("No.");
            }

            part(Fulfilledorders; "Fulfilled orders")
            {
                ApplicationArea = All;
                SubPageLink = "No." = FIELD("No.");
            }
            part(PurchaseHistory; "Purchase History Factbox")
            {
                ApplicationArea = All;
                SubPageLink = "No." = FIELD("No.");
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if Rec.Status = Rec.Status::Released then
            MakeEditable := false
        else
            MakeEditable := true;
    end;

    var
        MakeEditable: Boolean;
}
