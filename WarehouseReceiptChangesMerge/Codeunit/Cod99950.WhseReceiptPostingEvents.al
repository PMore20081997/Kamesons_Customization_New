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
        PurchRcptHeader."Confirmed Delivery Date" := WarehouseReceiptHeader."Confirmed Delivery Date";
        PurchRcptHeader."Confirmed Delivery Time" := WarehouseReceiptHeader."Confirmed Delivery Time";
        PurchRcptHeader."Confirmed Pallets" := WarehouseReceiptHeader."Confirmed Pallets";
        PurchRcptHeader."Confirmed Lifts" := WarehouseReceiptHeader."Confirmed Lifts";
        PurchRcptHeader."Confirmed Loose Boxes" := WarehouseReceiptHeader."Confirmed Loose Boxes";
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
}
