namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Ledger;

/// <summary>
/// Guards for the routing bins that now DEFINE an item's routing type.
///
/// WHY THIS EXISTS
///   Routing types used to live in Item."Routing Type". Two protections came
///   with that field and disappeared when it was removed:
///
///     1. An item's type could not be changed while stock still sat in the old
///        type's bin (Item_Ext.CheckMainWHBinEmpty).
///     2. A type was always fully "declared" — you could not half-create one.
///
///   Now that the bins are the source of truth, giving an item a new routing
///   type is just inserting a Bin Content row. Nothing would stop that row
///   being created without Max Qty (BULK / Static) or Number of Totes
///   (Flowrack), and the Put-Away engine reads exactly those fields to size the
///   face. A row missing them resolves to zero capacity, so every receipt for
///   that item would route to High Bay indefinitely, silently, with the item
///   looking correctly configured on screen.
///
///   These subscribers make that state unreachable:
///     * Adding / changing a routing bin requires its capacity fields.
///     * Removing a routing bin requires it to be empty first.
/// </summary>
codeunit 99970 "Routing Bin Guards NDPP"
{
    Access = Internal;
    Permissions = tabledata "Bin Content" = r,
                  tabledata Bin = r,
                  tabledata "Warehouse Entry" = r;

    [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnAfterInsertEvent, '', false, false)]
    local procedure BinContent_OnAfterInsert_RequireCapacity(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    begin
        if not RunTrigger then
            exit;
        CheckRoutingCapacityConfigured(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnAfterModifyEvent, '', false, false)]
    local procedure BinContent_OnAfterModify_RequireCapacity(var Rec: Record "Bin Content"; var xRec: Record "Bin Content"; RunTrigger: Boolean)
    begin
        if not RunTrigger then
            exit;
        CheckRoutingCapacityConfigured(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeDeleteEvent, '', false, false)]
    local procedure BinContent_OnBeforeDelete_RequireEmpty(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    var
        RoutingType: Enum "Item Routing Type NDPP";
        OnHandQty: Decimal;
    begin
        if not RunTrigger then
            exit;
        if Rec.IsTemporary() then
            exit;
        if not TryGetRoutingType(Rec, RoutingType) then
            exit;

        // Removing this row removes one of the item's routing types. Stock left
        // behind would be stranded in a bin the routing engine no longer
        // considers valid for the item.
        Rec.CalcFields("Quantity (Base)");
        OnHandQty := Rec."Quantity (Base)";
        if OnHandQty > 0 then
            Error(BinNotEmptyErr, Format(RoutingType), Rec."Bin Code", Rec."Item No.", OnHandQty, Rec."Location Code");
    end;

    /// <summary>
    /// Errors when a routing bin lacks the capacity field the Put-Away engine
    /// sizes it by. Applies only at MAIN — Receive staging bins are funnels and
    /// carry no per-item capacity.
    /// </summary>
    local procedure CheckRoutingCapacityConfigured(var BinContent: Record "Bin Content")
    var
        RoutingType: Enum "Item Routing Type NDPP";
    begin
        if BinContent.IsTemporary() then
            exit;
        if BinContent."Item No." = '' then
            exit;
        if BinContent."Location Code" <> KamWhseSetupLookup.GetMainLocation() then
            exit;
        if not TryGetRoutingType(BinContent, RoutingType) then
            exit;

        case RoutingType of
            RoutingType::BULK,
            RoutingType::"Static":
                // Sized by Max Qty x Qty per UoM.
                if BinContent."Max. Qty." <= 0 then
                    Error(MaxQtyMissingErr, Format(RoutingType), BinContent."Bin Code", BinContent."Item No.");
            RoutingType::Flowrack:
                // Sized by empty totes x qty per tote.
                if BinContent."Number of Totes in a Bin" <= 0 then
                    Error(TotesMissingErr, BinContent."Bin Code", BinContent."Item No.");
        end;
    end;

    /// <summary>
    /// The routing type of the bin behind a Bin Content row, or FALSE when the
    /// bin carries no routing flag (an ordinary bin this guard ignores).
    ///
    /// A bin flagged both Static and Flowrack — the shared decant face —
    /// reports Static, matching the Put-Away fill order.
    /// </summary>
    local procedure TryGetRoutingType(var BinContent: Record "Bin Content"; var RoutingType: Enum "Item Routing Type NDPP"): Boolean
    var
        Bin: Record Bin;
    begin
        if not Bin.Get(BinContent."Location Code", BinContent."Bin Code") then
            exit(false);

        case true of
            Bin.Bulk:
                RoutingType := RoutingType::BULK;
            Bin."Static":
                RoutingType := RoutingType::"Static";
            Bin.Flowrack:
                RoutingType := RoutingType::Flowrack;
            else
                exit(false); // Not a routing bin (includes High Bay).
        end;
        exit(true);
    end;

    var
        KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        MaxQtyMissingErr: Label 'Enter Max. Qty. for %1 bin %2 before assigning item %3 to it. The Put-Away engine sizes a %1 face by its Max. Qty., so without one the item would always be routed to High Bay.', Comment = '%1 = routing type; %2 = bin code; %3 = item no.';
        TotesMissingErr: Label 'Enter Number of Totes in a Bin for Flowrack bin %1 before assigning item %2 to it. The Put-Away engine sizes a Flowrack face by its tote count, so without one the item would always be routed to High Bay.', Comment = '%1 = bin code; %2 = item no.';
        BinNotEmptyErr: Label 'Cannot remove the %1 bin %2 from item %3. It still holds %4 base qty at location %5. Move that stock out first, otherwise it would be stranded in a bin no longer used for this item.', Comment = '%1 = routing type; %2 = bin code; %3 = item no.; %4 = qty; %5 = location';
}
