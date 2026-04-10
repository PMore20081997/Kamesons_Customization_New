query 99972 WarehouseEntryDecant
{
    Caption = 'WarehouseEntryDecant';
    QueryType = Normal;
    OrderBy = ascending(Expiration_Date);

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            //DataItemTableFilter = "Manufacturer Code" = filter(<> ''), "Zone Code" = filter(<> 'RECEIVE');
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
            // column(Manufacturer_Code; "Manufacturer Code")
            // {

            // }
            // column(Lot_No_; "Lot No.")
            // {

            // }
            column(Expiration_Date; "Expiration Date")
            {

            }
            column(Quantity; Quantity)
            {
                Method = Sum;
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;
}
