namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Purchases.Document;
using System.Security.AccessControl;

codeunit 99975 SecondCheck_Events
{
    trigger OnRun()
    begin

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", OnBeforeReleasePurchaseDoc, '', false, false)]
    local procedure OnBeforeReleasePurchaseDoc(var PurchaseHeader: Record "Purchase Header")
    begin
        // if PurchaseHeader."Second Check" <> '' then
        //     if not IsUserMemberOf(PurchaseHeader."Second Check") then
        //         Error('User %1 is not a member of the team specified in the Second Check field (%2) and cannot release this purchase order.', GetUserName(), PurchaseHeader."Second Check");

        if PurchaseHeader."Second Check" = '' then
            Error('The Second Check field must be filled in before releasing this purchase order.');   
    end;
    

    procedure GetUserName(UserSecurityId: Code[50]): Text[100]
    var
        Users: Record User;
    begin
        Users.Reset();
        Users.SetRange("User Security ID", UserSecurityId);
        if Users.FindFirst() then
            exit(Users."Full Name");

    end;
}
