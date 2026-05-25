namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;

/// <summary>
/// Mirrors Expiration Date onto the entry-relation row alongside Lot No.,
/// populated from Tracking Specification at the same time Lot No. is set.
/// See codeunit 99985 OnAfterInitFromTrackingSpec.
/// </summary>
tableextension 99960 WhseItemEntryRelation_Ext extends "Whse. Item Entry Relation"
{
    fields
    {
        field(99975; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
            DataClassification = CustomerContent;
        }
    }
}
