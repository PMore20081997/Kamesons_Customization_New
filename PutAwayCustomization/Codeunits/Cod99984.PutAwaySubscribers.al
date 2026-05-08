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
        if Rec.IsTemporary() then
            exit;
        PutAwayMgt.HandleBinCapacity(Rec);
    end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Post Receipt", OnCreatePutAwayDocOnBeforeCreatePutAwayRun, '', false, false)]
    // local procedure OnCreatePutAwayDocOnBeforeCreatePutAwayRun()
    // begin
    //     PutAwayMgt.StartExecution();
    // end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnBeforeInsertNewWhseActivLine, '', false, false)]
    local procedure OnBeforeInsertNewWhseActivLine(var NewWarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        // The new line came from a SplitLine() call — push the spillover to High-Bay.
        PutAwayMgt.RoutePutAwayLineAsHighBay(NewWarehouseActivityLine);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnSplitLineOnBeforeRenumberAllLines, '', false, false)]
    local procedure OnSplitLineOnBeforeRenumberAllLines(var LineSpacing: Integer)
    var
        Spacing: Integer;
    begin
        Spacing := PutAwayMgt.GetSplitLineSpacing();
        if Spacing > 0 then
            LineSpacing := Spacing;
    end;

    var
        PutAwayMgt: Codeunit "Put-Away Mgt. NDPP";
}
