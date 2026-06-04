namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;

/// <summary>
/// US 40488 — Returns the earliest Expiration Date currently held in a given
/// bin, for a specific item at a specific location. Ascending sibling of
/// Query 99981 "Whse Entry Lot Details NDPP".
/// Used by the put-away engine's HighBay-older-stock guard: if HighBay
/// already holds a lot older than the incoming line's expiry, the incoming
/// line is pushed to HighBay so the older HighBay batch reaches Main first
/// via decant (FEFO).
/// </summary>
query 99982 "Whse Entry Lot Det Asc NDPP"
{
    Caption = 'Warehouse Entry Lot Details Asc (NDPP)';
    QueryType = Normal;
    OrderBy = ascending(Expiration_Date);

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            column(Item_No_; "Item No.")
            {
            }
            column(Location_Code; "Location Code")
            {
            }
            column(Zone_Code; "Zone Code")
            {
            }
            column(Bin_Code; "Bin Code")
            {
            }
            column(Lot_No_; "Lot No.")
            {
            }
            column(Expiration_Date; "Expiration Date")
            {
            }
            column(Qty_Base; "Qty. (Base)")
            {
                Method = Sum;
            }
        }
    }
}
