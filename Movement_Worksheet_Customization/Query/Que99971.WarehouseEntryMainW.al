query 99971 Warehouse_Entry_Main
{
    Caption = 'Warehouse_Entry_Main';
    QueryType = Normal;

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            //DataItemTableFilter = "Location Code" = const('MAIN'), "Zone Code" = const('PICK BULK');
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
            column(Manufacturer_Code;"Manufacturer Code")
            {
                
            }
            column(Qty___Base_; "Qty. (Base)")
            {
                Method = Sum;
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;

    var
        G_Events: Codeunit "Events";
}
