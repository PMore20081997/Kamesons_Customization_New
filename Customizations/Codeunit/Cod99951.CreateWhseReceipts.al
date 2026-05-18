namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Request;
using System.Threading;
using Microsoft.Inventory.Location;

codeunit 99951 "Create Whse. Receipts"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        L_PurchaseHeader: Record "Purchase Header";
    begin
        L_PurchaseHeader.SetRange("Document Type", L_PurchaseHeader."Document Type"::Order);
        L_PurchaseHeader.SetRange(Status, L_PurchaseHeader.Status::Released);
        if L_PurchaseHeader.FindSet(true) then
            repeat
                if NeedsWhseReceipt(L_PurchaseHeader) then begin
                    ClearLastError();
                    if TryCreate(L_PurchaseHeader) then begin
                        if L_PurchaseHeader."Whse. Receipt Error" <> '' then begin
                            L_PurchaseHeader."Whse. Receipt Error" := '';
                            L_PurchaseHeader.Modify();
                        end;
                    end else begin
                        L_PurchaseHeader."Whse. Receipt Error" := CopyStr(GetLastErrorText(), 1, MaxStrLen(L_PurchaseHeader."Whse. Receipt Error"));
                        L_PurchaseHeader.Modify();
                    end;
                end;
            until L_PurchaseHeader.Next() = 0;
    end;

    [TryFunction]
    local procedure TryCreate(var PH: Record "Purchase Header")
    var
        GetSourceDocInbound: Codeunit "Get Source Doc. Inbound";
    begin
        GetSourceDocInbound.CreateFromPurchOrder(PH);
    end;

    local procedure NeedsWhseReceipt(PH: Record "Purchase Header"): Boolean
    var
        PL: Record "Purchase Line";
        Location: Record Location;
        WhseRequest: Record "Warehouse Request";
    begin
        WhseRequest.SetSourceFilter(Database::"Purchase Line", PH."Document Type".AsInteger(), PH."No.");
        WhseRequest.SetRange("Document Status", WhseRequest."Document Status"::Released);
        if not WhseRequest.IsEmpty() then
            exit(false);

        PL.SetRange("Document Type", PH."Document Type");
        PL.SetRange("Document No.", PH."No.");
        PL.SetRange(Type, PL.Type::Item);
        PL.SetFilter("Outstanding Quantity", '<>0');
        if PL.FindSet() then
            repeat
                if Location.Get(PL."Location Code") then
                    if Location."Require Receive" then
                        exit(true);
            until PL.Next() = 0;
        exit(false);
    end;
}
