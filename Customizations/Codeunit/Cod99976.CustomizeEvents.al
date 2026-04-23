namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Document;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Structure;

codeunit 99976 Customize_Events
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purchases Warehouse Mgt.", OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine, '', false, false)]
    local procedure OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine(var WarehouseReceiptLine: Record "Warehouse Receipt Line"; PurchaseLine: Record "Purchase Line")
    begin
        WarehouseReceiptLine."Manufacturer Code" := PurchaseLine."Manufacturer Code";
    end;

    // Restrict Main Warehouse to a single Item / Location / Zone / Bin combination.
    // Why: business rule — one item must live in exactly one bin at the Main location.
    [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeInsertEvent, '', false, false)]
    local procedure BinContent_OnBeforeInsert_RestrictOneBinPerItem(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    var
        L_ExistingBinContent: Record "Bin Content";
        L_MainLocation: Code[20];
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Item No." = '' then
            exit;

        L_MainLocation := G_Events.GetMainWarehouse();
        if L_MainLocation = '' then
            exit;
        if Rec."Location Code" <> L_MainLocation then
            exit;

        L_ExistingBinContent.SetRange("Location Code", Rec."Location Code");
        L_ExistingBinContent.SetRange("Item No.", Rec."Item No.");
        //L_ExistingBinContent.SetRange("Variant Code", Rec."Variant Code");
        L_ExistingBinContent.SetFilter("Bin Code", '<>%1', Rec."Bin Code");
        if not L_ExistingBinContent.IsEmpty() then begin
            L_ExistingBinContent.FindFirst();
            Error('Item %1 already exists at Main Location %2 in Zone %3 / Bin %4. Only one Item/Location/Zone/Bin combination is allowed.',
                Rec."Item No.", Rec."Location Code", L_ExistingBinContent."Zone Code", L_ExistingBinContent."Bin Code");
        end;
    end;

    var
        G_Events: Codeunit Events;
}
