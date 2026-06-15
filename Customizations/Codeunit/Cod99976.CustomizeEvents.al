namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.Ledger;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Activity;
using Microsoft.Inventory.Tracking;
using Microsoft.Warehouse.History;
using Microsoft.Warehouse.Tracking;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Sales.Document;
using Microsoft.Sales.Customer;
using Microsoft.Inventory.Item;

codeunit 99976 Customize_Events
{
    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purchases Warehouse Mgt.", OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine, '', false, false)]
    // local procedure OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine(var WarehouseReceiptLine: Record "Warehouse Receipt Line"; PurchaseLine: Record "Purchase Line")
    // begin
    //     WarehouseReceiptLine."Manufacturer Code" := PurchaseLine."Manufacturer Code";
    // end;


    //New++
    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromPostedWhseRcptLine, '', false, false)]
    local procedure OnAfterCopyTrackingFromPostedWhseRcptLine(PostedWhseRcptLine: Record "Posted Whse. Receipt Line"; var WarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        WarehouseActivityLine."Manufacturer Code" := PostedWhseRcptLine."Manufacturer Code";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Whse. Item Entry Relation", OnAfterInitFromTrackingSpec, '', false, false)]
    local procedure OnAfterInitFromTrackingSpec(TrackingSpecification: Record "Tracking Specification"; var WhseItemEntryRelation: Record "Whse. Item Entry Relation")
    begin
        WhseItemEntryRelation."Manufacturer Code" := TrackingSpecification."Manufacturer Code";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Posted Whse. Receipt Line", OnAfterCopyTrackingFromWhseItemEntryRelation, '', false, false)]
    local procedure OnAfterCopyTrackingFromWhseItemEntryRelation(var PostedWhseReceiptLine: Record "Posted Whse. Receipt Line"; WhseItemEntryRelation: Record "Whse. Item Entry Relation")
    begin
        PostedWhseReceiptLine."Manufacturer Code" := WhseItemEntryRelation."Manufacturer Code";
    end;
    //New--

    // Posted Whse. Receipt Line -> Warehouse Activity Line (Put-away from Warehouse Receipt).
    // Mirrors how Lot No. / Expiration Date flow into the activity line during put-away creation.
    // [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromPostedWhseRcptLine, '', false, false)]
    // local procedure WhseActLine_OnAfterCopyTrkgFromPostedWhseRcptLine(PostedWhseRcptLine: Record "Posted Whse. Receipt Line"; var WarehouseActivityLine: Record "Warehouse Activity Line")
    // begin
    //     WarehouseActivityLine."Manufacturer Code" := PostedWhseRcptLine."Manufacturer Code";
    // end;

    // Auto-fill Manufacturer Code from the source Purchase Line when Lot No. is
    // entered on Item Tracking Lines (Tracking Specification — used by Purchase
    // Order tracking). Source Type 39 = "Purchase Line".
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification", OnAfterValidateEvent, 'Lot No.', false, false)]
    local procedure TrackingSpec_OnAfterValidateLotNo_AssignMfrCode(var Rec: Record "Tracking Specification")
    var
        L_PurchLine: Record "Purchase Line";
        L_PurchDocType: Enum "Purchase Document Type";
    begin
        if Rec."Lot No." = '' then
            exit;
        if Rec."Source Type" <> Database::"Purchase Line" then
            exit;

        L_PurchDocType := Enum::"Purchase Document Type".FromInteger(Rec."Source Subtype");
        if L_PurchLine.Get(L_PurchDocType, Rec."Source ID", Rec."Source Ref. No.") then
            Rec."Manufacturer Code" := L_PurchLine."Manufacturer Code";
    end;

    // Same behavior for Warehouse Item Tracking Lines (used by Warehouse Receipt).
    // Source Type 5768 = "Warehouse Receipt Line"; navigate Whse Rcpt Line ->
    // Purchase Line via its Source No. / Source Line No.
    [EventSubscriber(ObjectType::Table, Database::"Whse. Item Tracking Line", OnAfterValidateEvent, 'Lot No.', false, false)]
    local procedure WhseItemTrkgLine_OnAfterValidateLotNo_AssignMfrCode(var Rec: Record "Whse. Item Tracking Line")
    var
        L_WhseRcptLine: Record "Warehouse Receipt Line";
        L_PurchLine: Record "Purchase Line";
    begin
        if Rec."Lot No." = '' then
            exit;
        if Rec."Source Type" <> Database::"Warehouse Receipt Line" then
            exit;
        if not L_WhseRcptLine.Get(Rec."Source ID", Rec."Source Ref. No.") then
            exit;
        if L_WhseRcptLine."Source Document" <> L_WhseRcptLine."Source Document"::"Purchase Order" then
            exit;
        if L_PurchLine.Get(L_PurchLine."Document Type"::Order, L_WhseRcptLine."Source No.", L_WhseRcptLine."Source Line No.") then
            Rec."Manufacturer Code" := L_PurchLine."Manufacturer Code";
    end;

    // Flow Dispensary / Retail flags from the selected Ship-to Address to the Sales Header.
    [EventSubscriber(ObjectType::Table, Database::"Sales Header", OnAfterValidateEvent, 'Ship-to Code', false, false)]
    local procedure SalesHeader_OnAfterValidateShipToCode_FlowFlags(var Rec: Record "Sales Header")
    var
        L_ShipToAddress: Record "Ship-to Address";
    begin
        if Rec."Sell-to Customer No." = '' then
            exit;
        if Rec."Ship-to Code" = '' then begin
            Rec.Dispensary := false;
            Rec."Retail " := false;
            exit;
        end;
        if L_ShipToAddress.Get(Rec."Sell-to Customer No.", Rec."Ship-to Code") then begin
            Rec.Dispensary := L_ShipToAddress.Dispensary;
            Rec."Retail " := L_ShipToAddress."Retail ";
        end;
    end;




    // Restrict Main Warehouse to a single Item / Location / Zone / Bin combination.
    // Why: business rule — one item must live in exactly one bin at the Main location.
    // [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeInsertEvent, '', false, false)]
    // local procedure BinContent_OnBeforeInsert_RestrictOneBinPerItem(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    // var
    //     L_ExistingBinContent: Record "Bin Content";
    //     L_MainLocation: Code[20];
    // begin
    //     if Rec.IsTemporary() then
    //         exit;
    //     if Rec."Item No." = '' then
    //         exit;

    //     L_MainLocation := G_Events.GetMainWarehouse();
    //     if L_MainLocation = '' then
    //         exit;
    //     if Rec."Location Code" <> L_MainLocation then
    //         exit;

    //     L_ExistingBinContent.SetRange("Location Code", Rec."Location Code");
    //     L_ExistingBinContent.SetRange("Item No.", Rec."Item No.");
    //     //L_ExistingBinContent.SetRange("Variant Code", Rec."Variant Code");
    //     L_ExistingBinContent.SetFilter("Bin Code", '<>%1', Rec."Bin Code");
    //     if not L_ExistingBinContent.IsEmpty() then begin
    //         L_ExistingBinContent.FindFirst();
    //         Error('Item %1 already exists at Main Location %2 in Zone %3 / Bin %4. Only one Item/Location/Zone/Bin combination is allowed.',
    //             Rec."Item No.", Rec."Location Code", L_ExistingBinContent."Zone Code", L_ExistingBinContent."Bin Code");
    //     end;
    // end;

    // (1) Force Max. Qty. := 0 when the row's Bin is flagged Flowrack.
    //     Flowrack faces are sized by tote count (Number of Totes in a Bin),
    //     not by a base-unit Max Qty, so any value > 0 here is misleading.
    // [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeInsertEvent, '', false, false)]
    // local procedure BinContent_OnBeforeInsert_ForceFlowrackMaxQty(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    // begin
    //     if Rec.IsTemporary() then
    //         exit;
    //     if IsFlowrackBin(Rec."Location Code", Rec."Bin Code") then
    //         Rec."Max. Qty." := 0;
    // end;

    // [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeModifyEvent, '', false, false)]
    // local procedure BinContent_OnBeforeModify_ForceFlowrackMaxQty(var Rec: Record "Bin Content"; var xRec: Record "Bin Content"; RunTrigger: Boolean)
    // begin
    //     if Rec.IsTemporary() then
    //         exit;
    //     if IsFlowrackBin(Rec."Location Code", Rec."Bin Code") then
    //         Rec."Max. Qty." := 0;
    // end;

    // (2) For BULK items, enforce one-bin-per-item at Main and Receive locations.
    //     A new Bin Content row for a BULK item is rejected if another Bin Content
    //     already exists for the same Item at the same Location in a different Bin.
    [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeInsertEvent, '', false, false)]
    local procedure BinContent_OnBeforeInsert_RestrictOneBinPerBulkItem(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    var
        L_Item: Record Item;
        L_ExistingBinContent: Record "Bin Content";
        L_MainLocation: Code[20];
        L_ReceiveLocation: Code[20];
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Item No." = '' then
            exit;

        L_MainLocation := G_KamWhseSetupLookup.GetMainLocation();
        L_ReceiveLocation := G_KamWhseSetupLookup.GetReceiveLocation();
        if (Rec."Location Code" <> L_MainLocation) and (Rec."Location Code" <> L_ReceiveLocation) then
            exit;

        if not L_Item.Get(Rec."Item No.") then
            exit;
        if L_Item."Routing Type" <> L_Item."Routing Type"::BULK then
            exit;

        L_ExistingBinContent.SetRange("Location Code", Rec."Location Code");
        L_ExistingBinContent.SetRange("Item No.", Rec."Item No.");
        L_ExistingBinContent.SetFilter("Bin Code", '<>%1', Rec."Bin Code");
        if L_ExistingBinContent.FindFirst() then
            Error('Item %1 (BULK) is already assigned to Bin %2 / Zone %3 at Location %4. A BULK item can occupy only one Bin per Location.',
                Rec."Item No.", L_ExistingBinContent."Bin Code", L_ExistingBinContent."Zone Code", Rec."Location Code");
    end;

    /// <summary>
    /// TRUE if the given Location + Bin combination has the Flowrack flag set
    /// on the Bin record (PutAwayCustomization Tab-Ext99956 field "Flowrack").
    /// </summary>
    // local procedure IsFlowrackBin(LocationCode: Code[10]; BinCode: Code[20]): Boolean
    // var
    //     L_Bin: Record Bin;
    // begin
    //     if (LocationCode = '') or (BinCode = '') then
    //         exit(false);
    //     if not L_Bin.Get(LocationCode, BinCode) then
    //         exit(false);
    //     exit(L_Bin.Flowrack);
    // end;

    var
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
}
