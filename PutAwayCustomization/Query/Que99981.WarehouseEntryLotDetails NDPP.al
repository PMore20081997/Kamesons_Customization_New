namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;

/// <summary>
/// US 40488 — returns the latest Expiration Date currently held in a given
/// Decant zone, for a specific item at a specific location.
/// Used by the put-away engine to compare incoming-stock expiry against the
/// existing decant-zone expiry: if incoming stock has an OLDER (or equal)
/// expiry, it goes to High-Bay so the decant face keeps the freshest stock.
/// </summary>
query 99981 "Whse Entry Lot Details NDPP"
{
    Caption = 'Warehouse Entry Lot Details (NDPP)';
    QueryType = Normal;
    OrderBy = descending(Expiration_Date);

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
