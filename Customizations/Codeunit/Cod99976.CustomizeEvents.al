namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.Ledger;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Activity;
using Microsoft.Inventory.Tracking;
using Microsoft.Warehouse.History;

codeunit 99976 Customize_Events
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purchases Warehouse Mgt.", OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine, '', false, false)]
    local procedure OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine(var WarehouseReceiptLine: Record "Warehouse Receipt Line"; PurchaseLine: Record "Purchase Line")
    begin
        WarehouseReceiptLine."Manufacturer Code" := PurchaseLine."Manufacturer Code";
    end;


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

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnAfterInsertEvent, '', false, false)]
    local procedure OnAfterInsertEventWE()
    var
        i: Integer;
    begin
        Clear(i);
    end;
    //New--

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

}
