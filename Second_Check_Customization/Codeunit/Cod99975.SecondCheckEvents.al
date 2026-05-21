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

    // On Reopen of a Purchase Order, clear the Second Check approval so the
    // change set must be re-approved before the PO can be released again.
    // Assigning fields directly (not Validate) avoids triggering the
    // SameUserSecondCheck guard on Purchase Header."Second Check".OnValidate.
    // The standard Modify(true) inside Release Purchase Document.Reopen
    // persists these values.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", OnReopenOnBeforePurchaseHeaderModify, '', false, false)]
    local procedure OnReopen_ClearSecondCheck(var PurchaseHeader: Record "Purchase Header")
    begin
        PurchaseHeader."Second Check" := PurchaseHeader."Second Check"::" ";
        PurchaseHeader."Second Check User" := '';
        PurchaseHeader."Second Check Date & Time" := 0DT;
    end;

    procedure ValidateSecondCheck(var PurchaseHeader: Record "Purchase Header")
    var
        L_UserSetup: Record "User Setup";
        L_SameUserSecondCheck: Label 'You cannot select Second Check as you are the one who created the purchase order. Please select another user or leave it blank.';
    begin
        if PurchaseHeader."Second Check" <> PurchaseHeader."Second Check"::" " then begin
            PurchaseHeader."Second Check User" := UserId;
            PurchaseHeader."Second Check Date & Time" := CurrentDateTime();
        end else begin
            PurchaseHeader."Second Check User" := '';
            PurchaseHeader."Second Check Date & Time" := 0DT;
        end;

        if L_UserSetup.Get(UserId) and L_UserSetup."Allow Second Check" then
            exit;

        if PurchaseHeader.SystemCreatedBy = UserSecurityId() then
            Error(L_SameUserSecondCheck);
    end;
}
