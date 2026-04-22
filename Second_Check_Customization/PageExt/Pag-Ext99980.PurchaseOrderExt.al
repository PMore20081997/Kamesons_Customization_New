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
            field("Second Check Date"; Rec."Second Check Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Second Check Date field.', Comment = '%';
                Editable = MakeEditable;
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
