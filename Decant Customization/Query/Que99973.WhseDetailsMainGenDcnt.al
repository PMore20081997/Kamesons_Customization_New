query 99973 WhseDetailsMainGenDcnt
{
    Caption = 'WhseDetailsMainGenDcnt';
    QueryType = Normal;

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            //DataItemTableFilter = "Location Code" = const('MAIN'), "Zone Code" = filter(<> 'PICK BULK');
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
            column(Package_No_; "Package No.")
            {

            }
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
