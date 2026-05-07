query 99952 WarehouseEntryByPackage
{
    Caption = 'WarehouseEntryByPackage';
    QueryType = Normal;
    OrderBy = ascending(Location_Code), ascending(Bin_Code), ascending(Expiration_Date);

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
            column(Manufacturer_Code; "Manufacturer Code")
            {
            }
            column(Variant_Code; "Variant Code")
            {
            }
            column(Unit_of_Measure_Code; "Unit of Measure Code")
            {
            }
            column(Lot_No_; "Lot No.")
            {
            }
            column(Expiration_Date; "Expiration Date")
            {
            }
            column(Package_No_; "Package No.")
            {
            }
            column(Qty_Base; "Qty. (Base)")
            {
                Method = Sum;
            }
        }
    }
}
