namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;
using System.Security.AccessControl;

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
            field(SystemCreatedAt; Rec.SystemCreatedAt)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the SystemCreatedAt field.', Comment = '%';
            }
            field(SystemCreatedBy; GetCreatedByUser(Rec.SystemCreatedBy))
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the SystemCreatedBy field.', Comment = '%';
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

    local procedure GetCreatedByUser(P_UserSecID: Guid): Code[50]
    var
        L_User: Record User;
    begin
        If L_User.Get(P_UserSecID) then
            exit(L_User."User Name");
    end;

    var
        MakeEditable: Boolean;
}
