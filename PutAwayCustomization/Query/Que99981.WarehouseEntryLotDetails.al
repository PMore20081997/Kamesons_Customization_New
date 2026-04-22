query 99981 WarehouseEntryLotDetails
{
    Caption = 'WarehouseEntryLotDetails';
    QueryType = Normal;
    OrderBy = descending(Expiration_Date);

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            //DataItemTableFilter = "Source Document" = filter('P.Order');
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
            // column(Quantity; Quantity)
            // {
            //     Method = Sum;
            // }
            column(Qty_Base; "Qty. (Base)")
            {
                Method = Sum;
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;
}
