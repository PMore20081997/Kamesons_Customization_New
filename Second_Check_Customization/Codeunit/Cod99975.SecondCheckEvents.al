namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Purchases.Document;
using Microsoft.Utilities;
using System.Security.AccessControl;
using System.Security.User;

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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", OnBeforeModifyPurchHeader, '', false, false)]
    local procedure OnBeforeModifyPurchHeader(var ToPurchHeader: Record "Purchase Header")
    begin

        if ToPurchHeader."Document Type" <> ToPurchHeader."Document Type"::Order then
            exit;

        ToPurchHeader."Second Check" := ToPurchHeader."Second Check"::" ";
        ToPurchHeader."Second Check Date & Time" := 0DT;
        ToPurchHeader."Second Check User" := '';
    end;
}
