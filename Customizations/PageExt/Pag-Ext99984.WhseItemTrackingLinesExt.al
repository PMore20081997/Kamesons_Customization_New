namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;

// On Whse. Item Tracking Lines (page 6550 — opened from Warehouse Receipt /
// Whse. Pick / Internal Put-away). After a partial receipt is posted, BC may
// re-create the Whse. Item Tracking Line for the remaining qty without
// carrying our custom Manufacture Code. Recover the value at display time
// from any existing Warehouse Entry for the same Item + Variant + Lot.
pageextension 99984 WhseItemTrackingLinesExt extends "Whse. Item Tracking Lines"
{
    layout
    {
        addafter("Expiration Date")
        {

            field("Manufacturer Code"; Rec."Manufacturer Code")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Manufacturer Code field.', Comment = '%';
            }
            field("Manufacturer Name"; Rec."Manufacturer Name")
            {
                ApplicationArea = All;
                Caption = 'Manufacturer Name';
                Editable = false;
                ToolTip = 'Specifies the name of the manufacturer for the Manufacturer Code.';
            }
        }
    }
    trigger OnAfterGetRecord()
    begin
        if (Rec."Manufacturer Code" = '') and (Rec."Lot No." <> '') then
            Rec."Manufacturer Code" := G_KamReservationMgt.LookupManufacturerCodeByLot(Rec."Item No.", Rec."Variant Code", Rec."Lot No.");
        Rec."Manufacturer Name" := CopyStr(G_TaskletCodeunits.GetManufacturerName(Rec."Manufacturer Code"), 1, MaxStrLen(Rec."Manufacturer Name"));
    end;

    var
        G_KamReservationMgt: Codeunit "Kam Reservation Mgt.";
        G_TaskletCodeunits: Codeunit Tasklet_Codeunits;
}
