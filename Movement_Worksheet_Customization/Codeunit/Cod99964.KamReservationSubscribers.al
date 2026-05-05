namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Requisition;
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
}
