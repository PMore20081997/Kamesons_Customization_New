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
        L_PurchaseHeader.SetRange("No.", '106079');
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
        // Hide-dialog variant: builds the Warehouse Receipt silently and does
        // not open the created receipt page (vanilla CreateFromPurchOrder calls
        // ShowDialog which is unwanted in a Job Queue / batch context).
        GetSourceDocInbound.CreateFromPurchOrderHideDialog(PH);
    end;

    // Mirrors the vanilla gate used by codeunit "Whse.-Purchase Release":
    //   - Document Type must be Order or Return Order
    //   - Header must be Released (so the standard Whse. Requests already exist)
    //   - At least one outstanding inventoriable Item line, non-drop-shipment,
    //     on a location where Location.RequireReceive is true.
    // No "is there already a Whse. Request?" gate — vanilla doesn't have one;
    // duplicate-protection is handled by Get Source Doc. Inbound itself.
    local procedure NeedsWhseReceipt(PH: Record "Purchase Header"): Boolean
    var
        PL: Record "Purchase Line";
        Location: Record Location;
    begin
        if not (PH."Document Type" in [PH."Document Type"::Order, PH."Document Type"::"Return Order"]) then
            exit(false);
        // if PH.Status <> PH.Status::Released then
        //     exit(false);

        PL.SetRange("Document Type", PH."Document Type");
        PL.SetRange("Document No.", PH."No.");
        PL.SetRange(Type, PL.Type::Item);
        PL.SetRange("Drop Shipment", false);
        PL.SetFilter("Outstanding Quantity", '<>0');
        if PL.FindSet() then
            repeat
                if PL.IsInventoriableItem() and not PL.IsWorkCenter() then
                    if Location.RequireReceive(PL."Location Code") then
                        exit(true);
            until PL.Next() = 0;
        exit(false);
    end;
}
