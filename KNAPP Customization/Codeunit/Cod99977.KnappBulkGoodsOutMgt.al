namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.InventoryDocument;
using Microsoft.Warehouse.Setup;
using Microsoft.Foundation.NoSeries;

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
// On pick posting the Goods Out Order is built from "BULK Load Unit Details"
// (filled by report 99956 when the BULK pick is created), not from the Sales
// Order: posting with Ship and Invoice deletes a fully invoiced Sales Order
// before OnAfterPostWhseActivHeader is raised.
//
// Partial posting: every posting sends its own GO Order with the quantity
// posted that time (Posted Invt. Pick Lines = the Qty. to Handle posted).
// Per pick line: the first posting updates the planned row (Qty. Handled,
// Qty. Outstanding), each later posting adds a row with a new Load Unit.
// Example, pick 100 posted as 60 / 30 / 10:
//   row 1 LU-001  Qty 100  Handled 60  Outstanding 40   -> GO qty 60
//   row 2 LU-002  Qty 100  Handled 30  Outstanding 10   -> GO qty 30
//   row 3 LU-003  Qty 100  Handled 10  Outstanding 0    -> GO qty 10
//
// The posting subscriber runs this codeunit with
// Codeunit.Run(..., WarehouseActivityHeader) so a Knapp failure never surfaces
// as an error after the pick posting.
codeunit 99977 "KNAPP BULK Goods Out Mgt."
{
    TableNo = "Warehouse Activity Header";
    SingleInstance = true;

    trigger OnRun()
    begin
        SendGoodsOutOrderForInvtPick(Rec);
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
        L_WhseActivHeader: Record "Warehouse Activity Header";
    begin
        if PostingCommitSuppressed then begin
            PostingCommitSuppressed := false;
            exit;
        end;

        if WhseActivHeader.Type <> WhseActivHeader.Type::"Invt. Pick" then
            exit;
        if WhseActivHeader."Source Document" <> WhseActivHeader."Source Document"::"Sales Order" then
            exit;
        // BULK picks only: their lines are in "BULK Load Unit Details".
        if not HasBulkLoadUnits(WhseActivHeader."No.") then
            exit;

        // Isolated run: the pick is already posted and committed, so a Knapp
        // failure must not raise an error on the posting.
        L_WhseActivHeader := WhseActivHeader;
        if not Codeunit.Run(Codeunit::"KNAPP BULK Goods Out Mgt.", L_WhseActivHeader) then
            if GuiAllowed() then
                Message(GoodsOutFailedMsg, WhseActivHeader."Source No.", GetLastErrorText());
    end;

    // ── GOODS OUT ORDER ───────────────────────────────────────────────────────

    var
        PostingCommitSuppressed: Boolean;
        GoodsOutFailedMsg: Label 'The inventory pick was posted, but the Goods Out Order for Sales Order %1 could not be sent to Knapp:\%2', Comment = '%1 = Sales Order No., %2 = error text';
        DefaultChannelCodeTok: Label 'KISOFT', Locked = true;
        ClientNumberTok: Label 'DEFAULT', Locked = true;
        LoadCarrierTok: Label 'FULL_CASE', Locked = true;
        GoodsOutOrderLineJsonTok: Label '{"lineReference":"%1","articleNumber":"%2","requestedQuantity":%3,"stationName":"%4"}', Locked = true;
        GoodsOutOrderJsonTok: Label '{"clientNumber":"%1","orderNumber":"%2","sheetNumber":%3,"loadCarrier":"%4","loadUnitCode":"%7","dispatchRampNumbers":[%5],"goodsOutOrderLines":[%6]}', Locked = true;
        // Pick posting (one GO Order per Load Unit): Knapp does not expect goodsOutOrderLines for now.
        GoodsOutOrderLoadUnitJsonTok: Label '{"clientNumber":"%1","orderNumber":"%2","sheetNumber":%3,"loadCarrier":"%4","startStationName":"%5","loadUnitCode":"%6","dispatchRampNumbers":[%7]}', Locked = true;
        NoChannelErr: Label 'No KiSoft Knapp Setup exists. Set up channel %1 before sending Goods Out Orders.', Comment = '%1 = default channel code';

    // Goods Out Orders for one posting of a BULK Inventory Pick: records the
    // posted quantities in "BULK Load Unit Details" and sends ONE GO Order PER
    // ROW (= per Load Unit) with the quantity posted this time and the row's
    // Load Unit as "loadUnitCode". The Sales Order is not needed.
    procedure SendGoodsOutOrderForInvtPick(var WhseActivHeader: Record "Warehouse Activity Header")
    var
        L_PostedInvtPickHeader: Record "Posted Invt. Pick Header";
        L_BulkLoadUnit: Record "BULK Load Unit Details";
        L_SalesLine: Record "Sales Line";
        KiSoftIntegration: Codeunit KiSoftIntegration;
        PostedRows: List of [Integer];
        EntryNo: Integer;
        QueueEntryNo: Integer;
        OrderLineRequest: Text;
        OrderRequest: Text;
        ArticleNumber: Text;
        StationName: Text;
        SentDateTime: DateTime;
        AnyQueued: Boolean;
    begin
        // The posting just made (newest posted pick of this Invt. Pick).
        L_PostedInvtPickHeader.SetRange("Invt Pick No.", WhseActivHeader."No.");
        if not L_PostedInvtPickHeader.FindLast() then
            exit;

        // Each posting is processed once.
        L_BulkLoadUnit.SetCurrentKey("Posted Invt. Pick No.");
        L_BulkLoadUnit.SetRange("Posted Invt. Pick No.", L_PostedInvtPickHeader."No.");
        if not L_BulkLoadUnit.IsEmpty() then
            exit;

        UpdateBulkLoadUnitsForPosting(WhseActivHeader."No.", L_PostedInvtPickHeader."No.", PostedRows);
        if PostedRows.Count() = 0 then
            exit;

        // Rows are saved even when nothing can be sent (no Knapp item, or a
        // GO Order Delete is still pending for the order).
        if GoodsOutOrderDeletePending(WhseActivHeader."Source No.") then begin
            Commit();
            exit;
        end;

        // One GO Order per row: header "loadUnitCode" = the row's Load Unit,
        // one line with the quantity posted this time.
        SentDateTime := CurrentDateTime();
        foreach EntryNo in PostedRows do
            if L_BulkLoadUnit.Get(EntryNo) then
                if IsKnappItem(L_BulkLoadUnit."Item No.") and (L_BulkLoadUnit."Qty. Handled" > 0) then begin
                    GetArticleAndStation(L_BulkLoadUnit."Item No.", L_BulkLoadUnit."Variant Code", ArticleNumber, StationName);

                    // Knapp does not expect goodsOutOrderLines for now.
                    // OrderLineRequest := StrSubstNo(GoodsOutOrderLineJsonTok,
                    //     Format(L_BulkLoadUnit."Sales Order Line No."), ArticleNumber, Format(L_BulkLoadUnit."Qty. Handled", 0, 9), StationName);
                    // OrderRequest := StrSubstNo(GoodsOutOrderJsonTok,
                    //     ClientNumberTok, WhseActivHeader."Source No.", 1, LoadCarrierTok,
                    //     Format(L_BulkLoadUnit."Dispatch Ramp No."), OrderLineRequest, L_BulkLoadUnit."Load Unit");
                    OrderRequest := StrSubstNo(GoodsOutOrderLoadUnitJsonTok,
                        ClientNumberTok, WhseActivHeader."Source No.", 1, LoadCarrierTok,
                        StationName, L_BulkLoadUnit."Load Unit", Format(L_BulkLoadUnit."Dispatch Ramp No."));
                    QueueEntryNo := InsertGoodsOutOrderQueueEntry(WhseActivHeader."Source No.", OrderRequest);
                    AnyQueued := true;

                    L_BulkLoadUnit."Sent to Knapp" := true;
                    L_BulkLoadUnit."Knapp Queue Entry No." := QueueEntryNo;
                    L_BulkLoadUnit."Sent to Knapp DateTime" := SentDateTime;
                    L_BulkLoadUnit.Modify();

                    // Keeps Knapp's own SENDGOODSOUTORDER job from sending the line
                    // again. Sales Line is gone when Ship and Invoice fully invoiced it.
                    if L_SalesLine.Get(L_SalesLine."Document Type"::Order, L_BulkLoadUnit."Sales Order No.", L_BulkLoadUnit."Sales Order Line No.") then
                        if not L_SalesLine."Sent to Knapp" then begin
                            L_SalesLine."Sent to Knapp" := true;
                            L_SalesLine.Remarks := '';
                            L_SalesLine.Modify();
                        end;
                end;
        Commit();

        if AnyQueued then
            KiSoftIntegration.CreateOrder(GetChannelCode());
    end;

    // Per pick line posted this time: the first posting updates the planned row,
    // a later posting adds a row with a new Load Unit. Returns the rows of this
    // posting in PostedRows.
    local procedure UpdateBulkLoadUnitsForPosting(InvtPickNo: Code[20]; PostedInvtPickNo: Code[20]; var PostedRows: List of [Integer])
    var
        L_PostedInvtPickLine: Record "Posted Invt. Pick Line";
        L_BulkLoadUnit: Record "BULK Load Unit Details";
        L_BulkLoadUnitNew: Record "BULK Load Unit Details";
        PostedQtyByLine: Dictionary of [Integer, Decimal];
        SourceLineNo: Integer;
        PostedQty: Decimal;
        HandledBefore: Decimal;
    begin
        // Posted quantity per sales line (a line can be split over bins / lots).
        L_PostedInvtPickLine.SetRange("No.", PostedInvtPickNo);
        if L_PostedInvtPickLine.FindSet() then
            repeat
                if PostedQtyByLine.ContainsKey(L_PostedInvtPickLine."Source Line No.") then
                    PostedQtyByLine.Set(L_PostedInvtPickLine."Source Line No.",
                        PostedQtyByLine.Get(L_PostedInvtPickLine."Source Line No.") + L_PostedInvtPickLine.Quantity)
                else
                    PostedQtyByLine.Add(L_PostedInvtPickLine."Source Line No.", L_PostedInvtPickLine.Quantity);
            until L_PostedInvtPickLine.Next() = 0;

        foreach SourceLineNo in PostedQtyByLine.Keys() do begin
            PostedQty := PostedQtyByLine.Get(SourceLineNo);

            L_BulkLoadUnit.Reset();
            L_BulkLoadUnit.SetCurrentKey("Invt. Pick No.", "Sales Order Line No.");
            L_BulkLoadUnit.SetRange("Invt. Pick No.", InvtPickNo);
            L_BulkLoadUnit.SetRange("Sales Order Line No.", SourceLineNo);
            L_BulkLoadUnit.CalcSums("Qty. Handled");
            HandledBefore := L_BulkLoadUnit."Qty. Handled";

            L_BulkLoadUnit.SetRange("Posted Invt. Pick No.", '');
            if L_BulkLoadUnit.FindFirst() then begin
                // First posting of this line: update the planned row.
                L_BulkLoadUnit."Qty. Handled" := PostedQty;
                L_BulkLoadUnit."Qty. Outstanding" := L_BulkLoadUnit.Quantity - HandledBefore - PostedQty;
                L_BulkLoadUnit."Posted Invt. Pick No." := PostedInvtPickNo;
                L_BulkLoadUnit.Modify();
                PostedRows.Add(L_BulkLoadUnit."Entry No.");
            end else begin
                // Later posting: new row, same line data, new Load Unit.
                L_BulkLoadUnit.SetRange("Posted Invt. Pick No.");
                if L_BulkLoadUnit.FindLast() then begin
                    L_BulkLoadUnitNew := L_BulkLoadUnit;
                    L_BulkLoadUnitNew."Entry No." := 0;
                    L_BulkLoadUnitNew."Load Unit" := GetNextLoadUnitNo();
                    L_BulkLoadUnitNew."Qty. Handled" := PostedQty;
                    L_BulkLoadUnitNew."Qty. Outstanding" := L_BulkLoadUnit.Quantity - HandledBefore - PostedQty;
                    L_BulkLoadUnitNew."Posted Invt. Pick No." := PostedInvtPickNo;
                    L_BulkLoadUnitNew."Sent to Knapp" := false;
                    L_BulkLoadUnitNew."Knapp Queue Entry No." := 0;
                    L_BulkLoadUnitNew."Sent to Knapp DateTime" := 0DT;
                    L_BulkLoadUnitNew.Insert(true);
                    PostedRows.Add(L_BulkLoadUnitNew."Entry No.");
                end;
            end;
        end;
    end;

    // Same rules as report 99956 CreateBulkLoadUnitDetails.
    local procedure GetNextLoadUnitNo(): Code[8]
    var
        L_WhseSetup: Record "Warehouse Setup";
        L_BulkLoadUnit: Record "BULK Load Unit Details";
        NoSeries: Codeunit "No. Series";
        LoadUnitNo: Code[20];
        LoadUnitTooLongErr: Label 'The number %1 from No. Series %2 is longer than %3 characters. Set up the Case Label Nos. series with numbers of max %3 characters (e.g. 00000001).', Comment = '%1 = number, %2 = No. Series code, %3 = max length';
    begin
        L_WhseSetup.Get();
        L_WhseSetup.TestField("Case Label Nos.");
        LoadUnitNo := NoSeries.GetNextNo(L_WhseSetup."Case Label Nos.");
        if StrLen(LoadUnitNo) > MaxStrLen(L_BulkLoadUnit."Load Unit") then
            Error(LoadUnitTooLongErr, LoadUnitNo, L_WhseSetup."Case Label Nos.", MaxStrLen(L_BulkLoadUnit."Load Unit"));
        exit(CopyStr(LoadUnitNo, 1, MaxStrLen(L_BulkLoadUnit."Load Unit")));
    end;

    local procedure HasBulkLoadUnits(InvtPickNo: Code[20]): Boolean
    var
        L_BulkLoadUnit: Record "BULK Load Unit Details";
    begin
        L_BulkLoadUnit.SetCurrentKey("Invt. Pick No.", "Sales Order Line No.");
        L_BulkLoadUnit.SetRange("Invt. Pick No.", InvtPickNo);
        exit(not L_BulkLoadUnit.IsEmpty());
    end;

    // Same guard as 90506 CheckOrderDeleteExistOrNot.
    local procedure GoodsOutOrderDeletePending(SalesOrderNo: Code[20]): Boolean
    var
        L_KnappDocumentQueue: Record "Knapp Document Queue";
    begin
        L_KnappDocumentQueue.SetRange("Document Type", L_KnappDocumentQueue."Document Type"::"GO Order Delete");
        L_KnappDocumentQueue.SetRange("Document Reference No.", SalesOrderNo);
        L_KnappDocumentQueue.SetRange(Status, L_KnappDocumentQueue.Status::New);
        exit(not L_KnappDocumentQueue.IsEmpty());
    end;

    // procedure CreateAndSendGoodsOutOrder(var SalesHeader: Record "Sales Header")
    // var
    //     KiSoftIntegration: Codeunit KiSoftIntegration;
    // begin
    //     if not CreateGoodsOutOrderQueueEntry(SalesHeader) then
    //         exit;
    //     Commit();

    //     KiSoftIntegration.CreateOrder(GetChannelCode());
    // end;

    // Returns true when a new "GO Order" entry was inserted for the order.
    // procedure CreateGoodsOutOrderQueueEntry(var SalesHeader: Record "Sales Header"): Boolean
    // var
    //     L_SalesLine: Record "Sales Line";
    //     L_SalesLineToUpdate: Record "Sales Line";
    //     OrderLineRequest: Text;
    //     OrderRequest: Text;
    //     ArticleNumber: Text;
    //     StationName: Text;
    // begin
    //     if not IsBulkGoodsOutOrder(SalesHeader) then
    //         exit(false);
    //     if GoodsOutOrderExists(SalesHeader."No.") then
    //         exit(false);

    //     L_SalesLine.SetRange("Document Type", SalesHeader."Document Type");
    //     L_SalesLine.SetRange("Document No.", SalesHeader."No.");
    //     L_SalesLine.SetRange(Type, L_SalesLine.Type::Item);
    //     L_SalesLine.SetRange("Sent to Knapp", false);
    //     L_SalesLine.SetFilter(Quantity, '>%1', 0);
    //     if not L_SalesLine.FindSet() then
    //         exit(false);

    //     repeat
    //         if IsKnappItem(L_SalesLine."No.") then begin
    //             GetArticleAndStation(L_SalesLine, ArticleNumber, StationName);

    //             if OrderLineRequest <> '' then
    //                 OrderLineRequest += ',';
    //             OrderLineRequest += StrSubstNo(GoodsOutOrderLineJsonTok,
    //                 Format(L_SalesLine."Line No."), ArticleNumber, Format(L_SalesLine.Quantity, 0, 9), StationName);

    //             // Modify through a second record: the loop is filtered on "Sent to Knapp".
    //             L_SalesLineToUpdate := L_SalesLine;
    //             L_SalesLineToUpdate."Sent to Knapp" := true;
    //             L_SalesLineToUpdate.Remarks := '';
    //             L_SalesLineToUpdate.Modify();
    //         end;
    //     until L_SalesLine.Next() = 0;

    //     if OrderLineRequest = '' then
    //         exit(false);

    //     OrderRequest := StrSubstNo(GoodsOutOrderJsonTok,
    //         ClientNumberTok, CopyStr(SalesHeader."No.", 1, 32), 1, LoadCarrierTok,
    //         Format(SalesHeader."Dispatch Ramp No."), OrderLineRequest);

    //     InsertGoodsOutOrderQueueEntry(SalesHeader."No.", OrderRequest);
    //     exit(true);
    // end;

    // Inserts the "GO Order" entry (Status New) and returns its Entry No.
    local procedure InsertGoodsOutOrderQueueEntry(SalesOrderNo: Code[20]; OrderRequest: Text): Integer
    var
        L_KnappDocumentQueue: Record "Knapp Document Queue";
        L_LastQueueEntry: Record "Knapp Document Queue";
        OStream: OutStream;
    begin
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
        L_KnappDocumentQueue."Document Reference No." := SalesOrderNo;
        L_KnappDocumentQueue.Request.CreateOutStream(OStream, TextEncoding::UTF8);
        OStream.WriteText(OrderRequest);
        L_KnappDocumentQueue.Insert();
        exit(L_KnappDocumentQueue."Entry No.");
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
    begin
        GetArticleAndStation(SalesLine."No.", SalesLine."Variant Code", ArticleNumber, StationName);
    end;

    local procedure GetArticleAndStation(ItemNo: Code[20]; VariantCode: Code[10]; var ArticleNumber: Text; var StationName: Text)
    var
        L_ItemReference: Record "Item Reference";
        L_KnappItemDetails: Record "Knapp Item Details";
        L_KnappStationNo: Record "Knapp Station Numbers";
    begin
        // Cleared per line so a line without a reference never inherits the
        // previous line's article / station.
        ArticleNumber := CopyStr(ItemNo, 1, 32);
        StationName := '';

        // Article Number reference of the line's own variant; fall back to any
        // Article Number reference of the item (the 90506 behaviour).
        L_ItemReference.SetRange("Item No.", ItemNo);
        L_ItemReference.SetRange("Reference Type", L_ItemReference."Reference Type"::"Article Number");
        L_ItemReference.SetRange("Variant Code", VariantCode);
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
