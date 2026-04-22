query 99972 WarehouseEntryReceive
{
    Caption = 'WarehouseEntryReceive';
    QueryType = Normal;
    OrderBy = ascending(Expiration_Date);

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            // DataItemTableFilter = "Manufacturer Code" = filter(<> ''), "Zone Code" = filter(<> 'RECEIVE');
            DataItemTableFilter = "Zone Code" = filter(<> 'RECEIVE');
            // column(Entry_No_; "Entry No.")
            // {

            // }
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
            column(Quantity; Quantity)
            {
                Method = Sum;
            }
            column(Qty_Base; "Qty. (Base)")
            {
                Method = Sum;
            }
            column(Qty_per_Unit_of_Measure; "Qty. per Unit of Measure")
            {
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;
}
