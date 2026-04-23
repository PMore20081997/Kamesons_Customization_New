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
        if PurchaseHeader."Second Check" <> PurchaseHeader."Second Check"::Approved then
            Error('The Second Check field must be Approved before releasing this purchase order.');
    end;
}
