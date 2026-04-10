query 99991 "LotNo. WHSE Entry MovementWrk"
{

    elements
    {
        dataitem("QueryElement1000000000"; "Warehouse Entry")
        {
            //DataItemTableFilter = "Lot No." = FILTER(<> ''), Quantity = filter(> 0), "Bin Code" = filter(<> 'RECEIPT'), "Bin Code" = filter(<> 'SHIPMENT'), "Bin Code" = filter(<> 'ADJUSTMENT');
            DataItemTableFilter = "Lot No." = FILTER(<> '');
            column(Item_No; "Item No.")
            {

            }
            column(Variant_Code; "Variant Code")
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
            column(Lot_No; "Lot No.")
            {
            }
            column(Status; "Package No.")
            {

            }
            //Azhar++ 28 March 2022
            column(Unit_of_Measure_Code; "Unit of Measure Code")
            {

            }
            //Azhar-- 28 March 2022
            // column(Sum_Quantity; Quantity)
            // {
            //     Method = Sum;

            // }
            column(Sum_Quantity; "Qty. (Base)")
            {
                Method = Sum;

            }
        }

    }
}

