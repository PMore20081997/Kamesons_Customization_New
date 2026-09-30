namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Warehouse.Activity;

// After an Inventory Pick of a BULK Sales Order is posted, builds the KiSoft
// Goods Out Order (Knapp Document Queue "GO Order") for that ONE order and
// sends it to Knapp.
//
// Mirrors Knapp Integration codeunit 90506 "KnappGenerateDocuments-KiSoft":
//   - KiSoft_GenerateGoodsOutOrderJobQueue / CreateGoodsOutOrderQueueEntry
//     (same JSON, same queue entry) but limited to the given order, and
//   - sends through the public 90507 KiSoftIntegration.CreateOrder
//     (POST /goodsOutOrder), which sends every New "GO Order" queue entry.
//
// The posting subscriber runs this codeunit with Codeunit.Run(..., SalesHeader)
// so a Knapp failure never surfaces as an error after the pick posting.
codeunit 99977 "KNAPP BULK Goods Out Mgt."
{
    TableNo = "Sales Header";
    SingleInstance = true;

    trigger OnRun()
    begin
        CreateAndSendGoodsOutOrder(Rec);
    end;

    // ── INVENTORY PICK POSTING ────────────────────────────────────────────────

    // Raised just before the posting Commit. When the caller suppressed the
    // commit (batch posting inside a bigger transaction), no HTTP call may run.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Activity-Post", 'OnAfterCode', '', false, false)]
    local procedure WhseActivityPost_OnAfterCode(var WarehouseActivityLine: Record "Warehouse Activity Line"; var SuppressCommit: Boolean; PrintDoc: Boolean)
    begin
        PostingCommitSuppressed := SuppressCommit;
    end;

    // Raised after the posting Commit (never reached in Preview Posting).
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Activity-Post", 'OnAfterPostWhseActivHeader', '', false, false)]
    local procedure WhseActivityPost_OnAfterPostWhseActivHeader(WhseActivHeader: Record "Warehouse Activity Header"; var PurchaseHeader: Record "Purchase Header"; var SalesHeader: Record "Sales Header"; var TransferHeader: Record "Transfer Header")
    var
        L_SalesHeader: Record "Sales Header";
    begin
        if PostingCommitSuppressed then begin
            PostingCommitSuppressed := false;
            exit;
        end;

        if WhseActivHeader.Type <> WhseActivHeader.Type::"Invt. Pick" then
            exit;
        if WhseActivHeader."Source Document" <> WhseActivHeader."Source Document"::"Sales Order" then
            exit;
        // Gone when the pick was posted with Ship and Invoice and fully invoiced.
        if not L_SalesHeader.Get(L_SalesHeader."Document Type"::Order, WhseActivHeader."Source No.") then
            exit;
        if not IsBulkGoodsOutOrder(L_SalesHeader) then
            exit;

        // Isolated run: the pick is already posted and committed, so a Knapp
        // failure must not raise an error on the posting.
        if not Codeunit.Run(Codeunit::"KNAPP BULK Goods Out Mgt.", L_SalesHeader) then
            if GuiAllowed() then
                Message(GoodsOutFailedMsg, L_SalesHeader."No.", GetLastErrorText());
    end;

    // ── GOODS OUT ORDER ───────────────────────────────────────────────────────

    var
        PostingCommitSuppressed: Boolean;
        GoodsOutFailedMsg: Label 'The inventory pick was posted, but the Goods Out Order for Sales Order %1 could not be sent to Knapp:\%2', Comment = '%1 = Sales Order No., %2 = error text';
        DefaultChannelCodeTok: Label 'KISOFT', Locked = true;
        ClientNumberTok: Label 'DEFAULT', Locked = true;
        LoadCarrierTok: Label 'FULL_CASE', Locked = true;
        GoodsOutOrderLineJsonTok: Label '{"lineReference":"%1","articleNumber":"%2","requestedQuantity":%3,"stationName":"%4"}', Locked = true;
        GoodsOutOrderJsonTok: Label '{"clientNumber":"%1","orderNumber":"%2","sheetNumber":%3,"loadCarrier":"%4","dispatchRampNumbers":[%5],"goodsOutOrderLines":[%6]}', Locked = true;
        NoChannelErr: Label 'No KiSoft Knapp Setup exists. Set up channel %1 before sending Goods Out Orders.', Comment = '%1 = default channel code';

    procedure CreateAndSendGoodsOutOrder(var SalesHeader: Record "Sales Header")
    var
        KiSoftIntegration: Codeunit KiSoftIntegration;
    begin
        if not CreateGoodsOutOrderQueueEntry(SalesHeader) then
            exit;
        Commit();

        KiSoftIntegration.CreateOrder(GetChannelCode());
    end;

    // Returns true when a new "GO Order" entry was inserted for the order.
    procedure CreateGoodsOutOrderQueueEntry(var SalesHeader: Record "Sales Header"): Boolean
    var
        L_SalesLine: Record "Sales Line";
        L_SalesLineToUpdate: Record "Sales Line";
        L_KnappDocumentQueue: Record "Knapp Document Queue";
        L_LastQueueEntry: Record "Knapp Document Queue";
        OStream: OutStream;
        OrderLineRequest: Text;
        OrderRequest: Text;
        ArticleNumber: Text;
        StationName: Text;
    begin
        if not IsBulkGoodsOutOrder(SalesHeader) then
            exit(false);
        if GoodsOutOrderExists(SalesHeader."No.") then
            exit(false);

        L_SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        L_SalesLine.SetRange("Document No.", SalesHeader."No.");
        L_SalesLine.SetRange(Type, L_SalesLine.Type::Item);
        L_SalesLine.SetRange("Sent to Knapp", false);
        L_SalesLine.SetFilter(Quantity, '>%1', 0);
        if not L_SalesLine.FindSet() then
            exit(false);

        repeat
            if IsKnappItem(L_SalesLine."No.") then begin
                GetArticleAndStation(L_SalesLine, ArticleNumber, StationName);

                if OrderLineRequest <> '' then
                    OrderLineRequest += ',';
                OrderLineRequest += StrSubstNo(GoodsOutOrderLineJsonTok,
                    Format(L_SalesLine."Line No."), ArticleNumber, Format(L_SalesLine.Quantity, 0, 9), StationName);

                // Modify through a second record: the loop is filtered on "Sent to Knapp".
                L_SalesLineToUpdate := L_SalesLine;
                L_SalesLineToUpdate."Sent to Knapp" := true;
                L_SalesLineToUpdate.Remarks := '';
                L_SalesLineToUpdate.Modify();
            end;
        until L_SalesLine.Next() = 0;

        if OrderLineRequest = '' then
            exit(false);

        OrderRequest := StrSubstNo(GoodsOutOrderJsonTok,
            ClientNumberTok, CopyStr(SalesHeader."No.", 1, 32), 1, LoadCarrierTok,
            Format(SalesHeader."Dispatch Ramp No."), OrderLineRequest);

        // Same numbering as 90506: Entry No. is unique per Document Type.
        L_LastQueueEntry.SetRange("Document Type", L_LastQueueEntry."Document Type"::"GO Order");
        L_KnappDocumentQueue.Init();
        if L_LastQueueEntry.FindLast() then
            L_KnappDocumentQueue."Entry No." := L_LastQueueEntry."Entry No." + 1
        else
            L_KnappDocumentQueue."Entry No." := 1;
        L_KnappDocumentQueue."Document Type" := L_KnappDocumentQueue."Document Type"::"GO Order";
        L_KnappDocumentQueue.Status := L_KnappDocumentQueue.Status::New;
        L_KnappDocumentQueue."User ID" := CopyStr(UserId(), 1, MaxStrLen(L_KnappDocumentQueue."User ID"));
        L_KnappDocumentQueue."Created Date/Time" := CurrentDateTime();
        L_KnappDocumentQueue."Document Reference No." := SalesHeader."No.";
        L_KnappDocumentQueue.Request.CreateOutStream(OStream, TextEncoding::UTF8);
        OStream.WriteText(OrderRequest);
        L_KnappDocumentQueue.Insert();
        exit(true);
    end;

    procedure IsBulkGoodsOutOrder(SalesHeader: Record "Sales Header"): Boolean
    begin
        exit(
            (SalesHeader."Document Type" = SalesHeader."Document Type"::Order) and
            SalesHeader."Knapp Order" and
            (SalesHeader."Knapp Order Type" = SalesHeader."Knapp Order Type"::BULK) and
            (SalesHeader.Status = SalesHeader.Status::Released));
    end;

    // Same duplicate guards as 90506 CheckOrderExistOrNot / CheckOrderDeleteExistOrNot.
    local procedure GoodsOutOrderExists(SalesOrderNo: Code[20]): Boolean
    var
        L_KnappDocumentQueue: Record "Knapp Document Queue";
    begin
        L_KnappDocumentQueue.SetRange("Document Type", L_KnappDocumentQueue."Document Type"::"GO Order");
        L_KnappDocumentQueue.SetRange("Document Reference No.", SalesOrderNo);
        L_KnappDocumentQueue.SetFilter(Status, '%1|%2', L_KnappDocumentQueue.Status::New, L_KnappDocumentQueue.Status::Completed);
        if not L_KnappDocumentQueue.IsEmpty() then
            exit(true);

        L_KnappDocumentQueue.SetRange("Document Type", L_KnappDocumentQueue."Document Type"::"GO Order Delete");
        L_KnappDocumentQueue.SetRange(Status, L_KnappDocumentQueue.Status::New);
        exit(not L_KnappDocumentQueue.IsEmpty());
    end;

    local procedure IsKnappItem(ItemNo: Code[20]): Boolean
    var
        L_Item: Record Item;
    begin
        if not L_Item.Get(ItemNo) then
            exit(false);
        exit(L_Item."Knapp Item");
    end;

    local procedure GetArticleAndStation(SalesLine: Record "Sales Line"; var ArticleNumber: Text; var StationName: Text)
    var
        L_ItemReference: Record "Item Reference";
        L_KnappItemDetails: Record "Knapp Item Details";
        L_KnappStationNo: Record "Knapp Station Numbers";
    begin
        // Cleared per line so a line without a reference never inherits the
        // previous line's article / station.
        ArticleNumber := CopyStr(SalesLine."No.", 1, 32);
        StationName := '';

        // Article Number reference of the line's own variant; fall back to any
        // Article Number reference of the item (the 90506 behaviour).
        L_ItemReference.SetRange("Item No.", SalesLine."No.");
        L_ItemReference.SetRange("Reference Type", L_ItemReference."Reference Type"::"Article Number");
        L_ItemReference.SetRange("Variant Code", SalesLine."Variant Code");
        if not L_ItemReference.FindFirst() then begin
            L_ItemReference.SetRange("Variant Code");
            if not L_ItemReference.FindFirst() then
                exit;
        end;

        if L_ItemReference."Variant Code" <> '' then
            ArticleNumber := L_ItemReference."Variant Code";

        L_KnappItemDetails.SetRange("Item No.", L_ItemReference."Item No.");
        L_KnappItemDetails.SetRange("Item Reference No.", L_ItemReference."Reference No.");
        L_KnappItemDetails.SetRange("Item Reference Type", L_ItemReference."Reference Type");
        if L_ItemReference."Variant Code" <> '' then
            L_KnappItemDetails.SetRange("Item Variant Code", L_ItemReference."Variant Code");
        if not L_KnappItemDetails.FindFirst() then
            exit;

        L_KnappStationNo.SetRange("Station Number", L_KnappItemDetails."Knapp Station Number");
        if not L_KnappStationNo.IsEmpty() then
            StationName := L_KnappItemDetails."Knapp Station Number";
    end;

    local procedure GetChannelCode(): Code[10]
    var
        L_KiSoftKnappSetup: Record "KiSoft Knapp Setup";
    begin
        if L_KiSoftKnappSetup.Get(DefaultChannelCodeTok) then
            exit(DefaultChannelCodeTok);
        if not L_KiSoftKnappSetup.FindFirst() then
            Error(NoChannelErr, DefaultChannelCodeTok);
        exit(CopyStr(L_KiSoftKnappSetup."Channel Code", 1, 10));
    end;
}
