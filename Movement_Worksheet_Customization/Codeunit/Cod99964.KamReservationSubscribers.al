namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Ledger;
//using Microsoft.Inventory.Reservation;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.Journal;
using Microsoft.Warehouse.Tracking;

/// <summary>
/// Event subscribers ONLY. Each subscriber is one line that delegates
/// to a management codeunit. This keeps subscribers unit-testable in
/// isolation (you can call the management codeunit directly in a test
/// without firing the event).
/// </summary>
codeunit 99964 "Kam Reservation Subscribers"
{
    Access = Internal;

    var
        ReservationMgt: Codeunit "Kam Reservation Mgt.";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnInsertTransHeaderOnBeforeTransHeaderModify, '', false, false)]
    local procedure OnInsertTransHeader(var TransHeader: Record "Transfer Header")
    begin
        ReservationMgt.SetTransferAsDirect(TransHeader);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnAfterInsertTransLine, '', false, false)]
    local procedure OnAfterInsertTransLine(var TransLine: Record "Transfer Line"; var ReqLine: Record "Requisition Line")
    begin
        ReservationMgt.CreateLotReservationForTransferLine(TransLine, ReqLine);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", OnAfterCopyTrackingFromReservEntry, '', false, false)]
    local procedure OnAfterCopyTrackingFromReservEntry(var ReservationEntry: Record "Reservation Entry"; FromReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry."Package No." := FromReservationEntry."Package No.";
        ReservationEntry."Manufacturer Code" := FromReservationEntry."Manufacturer Code";
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", OnBeforeAddToGlobalRecordSet, '', false, false)]
    local procedure ItemTrackingLines_OnBeforeAddToGlobalRecordSet(var TrackingSpecification: Record "Tracking Specification"; EntriesExist: Boolean; CurrentSignFactor: Integer; var TempTrackingSpecification: Record "Tracking Specification" temporary)
    begin
        ReservationMgt.EnrichTrackingSpecificationWithManufacturer(TrackingSpecification, TempTrackingSpecification);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromWhseItemTrackingLine, '', false, false)]
    local procedure OnAfterCopyTrkgFromWhseItemTrkgLine(var WarehouseActivityLine: Record "Warehouse Activity Line"; WhseItemTrackingLine: Record "Whse. Item Tracking Line")
    begin
        WarehouseActivityLine."Manufacturer Code" := WhseItemTrackingLine."Manufacturer Code";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromSpec, '', false, false)]
    local procedure OnAfterCopyTrkgFromSpec(var WarehouseActivityLine: Record "Warehouse Activity Line"; TrackingSpecification: Record "Tracking Specification")
    begin
        ReservationMgt.PopulateActivityLineMfgFromSpec(WarehouseActivityLine, TrackingSpecification);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Journal Line", OnAfterCopyTrackingFromWhseActivityLine, '', false, false)]
    local procedure OnAfterCopyTrkgFromWhseActLine(var WarehouseJournalLine: Record "Warehouse Journal Line"; WarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        WarehouseJournalLine."Manufacturer Code" := WarehouseActivityLine."Manufacturer Code";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnAfterCopyTrackingFromWhseJnlLine, '', false, false)]
    local procedure OnAfterCopyTrkgFromWhseJnlLine(var WarehouseEntry: Record "Warehouse Entry"; WarehouseJournalLine: Record "Warehouse Journal Line")
    begin
        WarehouseEntry."Manufacturer Code" := WarehouseJournalLine."Manufacturer Code";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnAfterCopyTrackingFromNewWhseJnlLine, '', false, false)]
    local procedure OnAfterCopyTrkgFromNewWhseJnlLine(var WarehouseEntry: Record "Warehouse Entry"; WarehouseJournalLine: Record "Warehouse Journal Line")
    begin
        WarehouseEntry."Manufacturer Code" := WarehouseJournalLine."Manufacturer Code";
    end;

    // Catch-all for pick line creation: fires just before the activity line is inserted.
    // OnAfterCopyTrackingFromSpec (called earlier in the same code path) handles the
    // case when Whse. Item Tracking Lines exist. This covers the common scenario where
    // those lines were already purged after put-away registration.
    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnBeforeInsertEvent, '', false, false)]
    local procedure WhseActLine_OnBeforeInsert_FillMfrCode(var Rec: Record "Warehouse Activity Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if not (Rec."Activity Type" in [Rec."Activity Type"::Pick, Rec."Activity Type"::"Invt. Pick"]) then
            exit;
        if Rec."Lot No." = '' then
            exit;
        if Rec."Manufacturer Code" <> '' then
            exit;
        Rec."Manufacturer Code" := ReservationMgt.LookupManufacturerCodeByLot(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
        if Rec."Manufacturer Code" = '' then
            Rec."Manufacturer Code" := ReservationMgt.LookupManufacturerCodeFromILE(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
    end;

    // Fallback for Warehouse Entries created during Warehouse Shipment posting.
    // During shipment posting the Warehouse Journal Line is built from Tracking
    // Specifications / Reservation Entries rather than from the Warehouse Activity
    // Line, so the OnAfterCopyTrackingFromWhseJnlLine chain does not carry the
    // Manufacturer Code. This subscriber catches that gap and looks it up by lot,
    // mirroring the same pattern used for Item Ledger Entries below.
    [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnBeforeInsertEvent, '', false, false)]
    local procedure WhseEntry_OnBeforeInsert_FillMfrCode(var Rec: Record "Warehouse Entry"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Manufacturer Code" <> '' then
            exit;
        if Rec."Lot No." = '' then
            exit;
        Rec."Manufacturer Code" := ReservationMgt.LookupManufacturerCodeByLot(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
        if Rec."Manufacturer Code" = '' then
            Rec."Manufacturer Code" := ReservationMgt.LookupManufacturerCodeFromILE(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
    end;

    // Fallback for outbound Item Ledger Entries: fires before the ILE is written.
    // Covers cases where the Reservation Entry did not carry the Manufacturer Code
    // (e.g. stock received before this customisation was deployed). Looks up the code
    // from existing positive ILEs or Warehouse Entries for the same lot.
    [EventSubscriber(ObjectType::Table, Database::"Item Ledger Entry", OnBeforeInsertEvent, '', false, false)]
    local procedure ILE_OnBeforeInsert_FillMfrCode(var Rec: Record "Item Ledger Entry"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Manufacturer Code" <> '' then
            exit;
        if Rec."Lot No." = '' then
            exit;
        Rec."Manufacturer Code" := ReservationMgt.LookupManufacturerCodeFromILE(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
        if Rec."Manufacturer Code" = '' then
            Rec."Manufacturer Code" := ReservationMgt.LookupManufacturerCodeByLot(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
    end;
}
