namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;
using Microsoft.Inventory.Tracking;

/// <summary>
/// Populates the custom "Expiration Date" field on Whse. Item Entry Relation
/// from the source Tracking Specification at the same moment standard BC
/// initialises Lot No. / Serial No. on that row.
/// </summary>
codeunit 99985 "Whse. Item Entry Rel. Events"
{
    [EventSubscriber(ObjectType::Table, Database::"Whse. Item Entry Relation", OnAfterInitFromTrackingSpec, '', false, false)]
    local procedure OnAfterInitFromTrackingSpec(var WhseItemEntryRelation: Record "Whse. Item Entry Relation"; TrackingSpecification: Record "Tracking Specification")
    begin
        WhseItemEntryRelation."Expiration Date" := TrackingSpecification."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Whse. Item Entry Relation", OnAfterSetSourceFilter, '', false, false)]
    local procedure OnAfterSetSourceFilter(var WhseItemEntryRelation: Record "Whse. Item Entry Relation")
    begin
        WhseItemEntryRelation.SetCurrentKey("Expiration Date");
        WhseItemEntryRelation.SetAscending("Expiration Date", true);
    end;
}
