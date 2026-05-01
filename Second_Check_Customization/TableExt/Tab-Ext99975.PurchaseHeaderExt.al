namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;
using System.Security.AccessControl;
using Microsoft.CRM.Team;
using System.Security.User;

tableextension 99975 Purchase_Header_Ext extends "Purchase Header"
{
    fields
    {
        field(99971; "Second Check"; Enum "Second Check Status")
        {

            trigger OnValidate()
            var
                L_SecondCheck_Events: Codeunit SecondCheck_Events;
                L_UserSetup: Record "User Setup";
            begin
                Rec."Second Check User" := UserId;
                Rec."Second Check Date & Time" := CurrentDateTime();

                if L_UserSetup.Get(UserId) and L_UserSetup."Allow Second Check" then
                    exit;

                if SystemCreatedBy = UserSecurityId() then begin
                    Error(L_SameUserSecondCheck);
                end; //Temporary


            end;
        }
        field(99972; "Second Check User"; Code[100])
        {
            TableRelation = User."User Name";
        }
        field(99973; "Second Check Date & Time"; DateTime)
        {

        }
    }

    var
        L_SameUserSecondCheck: Label 'You cannot select Second Check as you are the one who created the purchase order. Please select another user or leave it blank.';
}
