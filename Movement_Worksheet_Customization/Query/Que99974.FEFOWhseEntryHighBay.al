query 99974 "FEFO Whse Entry HIGHBAY"
{
    Caption = 'FEFO Warehouse Entry HIGHBAY';
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
            column(Package_No_; "Package No.")
            {

            }
            column(Unit_of_Measure_Code; "Unit of Measure Code")
            {
            }
            column(Expiration_Date; "Expiration Date")
            {
            }
            column(Quantity; Quantity)
            {
                Method = Sum;
            }
        }
    }
}
