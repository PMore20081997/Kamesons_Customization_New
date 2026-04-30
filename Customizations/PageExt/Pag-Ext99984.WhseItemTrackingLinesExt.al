namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;

// On Whse. Item Tracking Lines (page 6550 — opened from Warehouse Receipt /
// Whse. Pick / Internal Put-away). After a partial receipt is posted, BC may
// re-create the Whse. Item Tracking Line for the remaining qty without
// carrying our custom Manufacture Code. Recover the value at display time
// from any existing Warehouse Entry for the same Item + Variant + Lot.
pageextension 99984 WhseItemTrackingLinesExt extends "Whse. Item Tracking Lines"
{
    trigger OnAfterGetRecord()
    begin
        if (Rec."Manufacture Code" = '') and (Rec."Lot No." <> '') then
            Rec."Manufacture Code" := G_KamReservationMgt.LookupManufacturerCodeByLot(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
    end;

    var
        G_KamReservationMgt: Codeunit "Kam Reservation Mgt.";
}
