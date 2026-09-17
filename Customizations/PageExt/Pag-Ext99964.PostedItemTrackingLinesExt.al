namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Tracking;

// Show the Manufacturer on the Posted Item Tracking Lines (page 6511,
// sourced from Item Ledger Entry). The Manufacturer Code/Name are already
// populated on the Item Ledger Entry by the posting-time subscribers
// (Kam Reservation Subscribers), so this is display only.
pageextension 99964 PostedItemTrackingLinesExt extends "Posted Item Tracking Lines"
{
    layout
    {
        addafter("Package No.")
        {
            field("Manufacturer Code"; Rec."Manufacturer Code")
            {
                ApplicationArea = All;
                Caption = 'Manufacturer Code';
                Editable = false;
                ToolTip = 'Specifies the value of the Manufacturer Code field.';
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
}
