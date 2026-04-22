namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;
using System.Security.AccessControl;
using Microsoft.CRM.Team;

tableextension 99975 Purchase_Header_Ext extends "Purchase Header"
{
    fields
    {
        field(99971; "Second Check"; Code[20])
        {
            TableRelation = "Salesperson/Purchaser".Code;
            trigger OnValidate()
            var
                L_SecondCheck_Events: Codeunit SecondCheck_Events;
            begin
                // if SystemCreatedBy = UserSecurityId() then begin
                //     Error(L_SameUserSecondCheck);
                // end; //Temporary

                Rec."Second Check User" := UserId;
                Rec."Second Check Date" := CurrentDateTime();
            end;
        }
        field(99972; "Second Check User"; Code[100])
        {
            TableRelation = User."User Name";
        }
        field(99973; "Second Check Date"; DateTime)
        {

        }
    }

    var
        L_SameUserSecondCheck: Label 'You cannot select Second Check as yourself as you are the one who created the purchase order. Please select another user or leave it blank.';
}
