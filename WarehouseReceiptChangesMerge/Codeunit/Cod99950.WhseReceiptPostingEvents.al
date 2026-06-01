namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Posting;
using Microsoft.Purchases.History;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.History;

// Carries the custom Warehouse Receipt Header fields (99950..99967) onto the
// Posted Purchase Receipt header. Posted Whse. Receipt Header receives them
// automatically because Whse.-Post Receipt does TransferFields and the field
// IDs match — no subscriber needed there.
codeunit 99950 "Whse Rcpt Posting Events"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", OnBeforePurchRcptHeaderInsert, '', false, false)]
    local procedure CopyWhseRcptFieldsToPurchRcptHeader(
        var PurchRcptHeader: Record "Purch. Rcpt. Header";
        var PurchaseHeader: Record "Purchase Header";
        CommitIsSupressed: Boolean;
        WarehouseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceive: Boolean;
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WhseShip: Boolean)
    begin
        if not WhseReceive then
            exit;
        if WarehouseReceiptHeader."No." = '' then
            exit;

        PurchRcptHeader."Transportation Arranged By" := WarehouseReceiptHeader."Transportation Arranged By";
        PurchRcptHeader."Preferred Delivery Date" := WarehouseReceiptHeader."Preferred Delivery Date";
        PurchRcptHeader."Expected Delivery Date" := WarehouseReceiptHeader."Expected Delivery Date";
        PurchRcptHeader."Expected Delivery Time" := WarehouseReceiptHeader."Expected Delivery Time";
        PurchRcptHeader."Expected Pallets" := WarehouseReceiptHeader."Expected Pallets";
        PurchRcptHeader."Expected Lifts" := WarehouseReceiptHeader."Expected Lifts";
        PurchRcptHeader."Expected Loose Boxes" := WarehouseReceiptHeader."Expected Loose Boxes";
        PurchRcptHeader."Received Lifts" := WarehouseReceiptHeader."Received Lifts";
        PurchRcptHeader."Received Loose Boxes" := WarehouseReceiptHeader."Received Loose Boxes";
        PurchRcptHeader."Received Pallets" := WarehouseReceiptHeader."Received Pallets";
        PurchRcptHeader."No. of Items" := WarehouseReceiptHeader."No. of Items";
        PurchRcptHeader.Comments := WarehouseReceiptHeader.Comments;
        PurchRcptHeader."Receiving Status" := WarehouseReceiptHeader."Receiving Status";
        PurchRcptHeader."Received Date" := WarehouseReceiptHeader."Received Date";
        PurchRcptHeader."Received Time" := WarehouseReceiptHeader."Received Time";
        PurchRcptHeader."Shipping Carrier" := WarehouseReceiptHeader."Shipping Carrier";
        PurchRcptHeader."Delivery Term" := WarehouseReceiptHeader."Delivery Term";
        PurchRcptHeader."Vehicle Registration No" := WarehouseReceiptHeader."Vehicle Registration No";
    end;

    // Mirror Expected/Received Pallets from the Warehouse Receipt Header onto
    // every linked Purchase Header so the PO page reflects the latest values
    // entered on the receipt. WRH lines point at Purchase Lines via Source
    // Type 39 + Source Subtype (Doc Type) + Source No. (PO No.).
    [EventSubscriber(ObjectType::Table, Database::"Warehouse Receipt Header", OnAfterModifyEvent, '', false, false)]
    local procedure SyncPalletsToPurchaseHeaderOnWhseRcptModify(var Rec: Record "Warehouse Receipt Header"; var xRec: Record "Warehouse Receipt Header"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if (Rec."Expected Pallets" = xRec."Expected Pallets") and (Rec."Received Pallets" = xRec."Received Pallets") then
            exit;
        SyncPalletsToLinkedPurchaseHeaders(Rec);
    end;

    // // Also push on insert (covers initial creation paths that bypass Modify).
    // [EventSubscriber(ObjectType::Table, Database::"Warehouse Receipt Header", OnAfterInsertEvent, '', false, false)]
    // local procedure SyncPalletsToPurchaseHeaderOnWhseRcptInsert(var Rec: Record "Warehouse Receipt Header"; RunTrigger: Boolean)
    // begin
    //     if Rec.IsTemporary() then
    //         exit;
    //     SyncPalletsToLinkedPurchaseHeaders(Rec);
    // end;

    local procedure SyncPalletsToLinkedPurchaseHeaders(var WhseRcptHeader: Record "Warehouse Receipt Header")
    var
        L_WhseRcptLine: Record "Warehouse Receipt Line";
        L_PurchHeader: Record "Purchase Header";
        L_PurchDocType: Enum "Purchase Document Type";
        L_LastSourceNo: Code[20];
        L_LastSubtype: Integer;
    begin
        L_WhseRcptLine.SetCurrentKey("Source Type", "Source Subtype", "Source No.");
        L_WhseRcptLine.SetRange("No.", WhseRcptHeader."No.");
        L_WhseRcptLine.SetRange("Source Type", Database::"Purchase Line");
        if not L_WhseRcptLine.FindSet() then
            exit;
        repeat
            // Dedupe consecutive lines hitting the same PO (key is sorted, so
            // we only need to compare to the previous PO key).
            if (L_WhseRcptLine."Source No." <> L_LastSourceNo) or (L_WhseRcptLine."Source Subtype" <> L_LastSubtype) then begin
                L_LastSourceNo := L_WhseRcptLine."Source No.";
                L_LastSubtype := L_WhseRcptLine."Source Subtype";
                L_PurchDocType := Enum::"Purchase Document Type".FromInteger(L_WhseRcptLine."Source Subtype");
                if L_PurchHeader.Get(L_PurchDocType, L_WhseRcptLine."Source No.") then begin
                    L_PurchHeader."Expected Pallets" := WhseRcptHeader."Expected Pallets";
                    L_PurchHeader."Received Pallets" := WhseRcptHeader."Received Pallets";
                    L_PurchHeader.Modify(false);
                end;
            end;
        until L_WhseRcptLine.Next() = 0;
    end;
}
