namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Document;

/// <summary>
/// US 40488 — Event subscribers for the Put-Away routing engine.
///
/// This codeunit contains ZERO business logic — every subscriber forwards
/// straight into "Put-Away Mgt. NDPP". This split is deliberate:
///   * Subscribers cannot easily be unit-tested (they only fire from BC events)
///   * Putting logic in a procedure on a separate codeunit means the test
///     codeunit can call it directly with crafted input.
/// </summary>
codeunit 99984 "Put-Away Subscribers NDPP"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Put-away", OnBeforeWhseActivLineInsert, '', false, false)]
    local procedure OnBeforeWhseActivLineInsert(var WarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        PutAwayMgt.RoutePutAwayLine(WarehouseActivityLine);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterInsertEvent, '', false, false)]
    local procedure OnAfterInsertWhseActivityLine(var Rec: Record "Warehouse Activity Line")
    begin
        // Pre-filter at subscriber level — this event fires for every Whse Activity
        // Line insert system-wide (picks, movements, transfers, all locations). The
        // cheap field reads here avoid codeunit dispatch + Item.Get for unrelated lines.
        if Rec.IsTemporary() then
            exit;
        if not IsPutAwayPlaceFromPO(Rec) then
            exit;
        PutAwayMgt.HandleBinCapacity(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnBeforeInsertNewWhseActivLine, '', false, false)]
    local procedure OnBeforeInsertNewWhseActivLine(var NewWarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        // Same system-wide event — only act when the split line belongs to OUR flow.
        if not IsPutAwayPlaceFromPO(NewWarehouseActivityLine) then
            exit;
        // The new line came from a SplitLine() call — push the spillover to High-Bay.
        PutAwayMgt.RoutePutAwayLineAsHighBay(NewWarehouseActivityLine);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnSplitLineOnBeforeRenumberAllLines, '', false, false)]
    local procedure OnSplitLineOnBeforeRenumberAllLines(var LineSpacing: Integer)
    var
        Spacing: Integer;
    begin
        // GetSplitLineSpacing returns 0 unless we're mid-split inside HandleBinCapacity,
        // so callers from unrelated split flows don't get our 5000 spacing.
        Spacing := PutAwayMgt.GetSplitLineSpacing();
        if Spacing > 0 then
            LineSpacing := Spacing;
    end;

    /// <summary>
    /// Cheap shared check — TRUE only for Put-Away Place lines from a Purchase
    /// Order. Used by every system-wide subscriber to bail before calling into
    /// the management codeunit. Mirrors PutAwayMgt.IsEligibleForRouting but
    /// without the Receive-Location lookup (the Mgt codeunit re-checks that).
    /// </summary>
    local procedure IsPutAwayPlaceFromPO(var WhseActLine: Record "Warehouse Activity Line"): Boolean
    begin
        if WhseActLine."Activity Type" <> WhseActLine."Activity Type"::"Put-away" then
            exit(false);
        if WhseActLine."Action Type" <> WhseActLine."Action Type"::Place then
            exit(false);
        if WhseActLine."Source Document" <> WhseActLine."Source Document"::"Purchase Order" then
            exit(false);
        exit(true);
    end;

    var
        PutAwayMgt: Codeunit "Put-Away Mgt. NDPP";
}
