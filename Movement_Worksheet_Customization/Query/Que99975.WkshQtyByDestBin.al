query 99975 "Wksh Qty By Dest Bin NDPP"
{
    Caption = 'Worksheet Qty by Destination Bin';
    QueryType = Normal;

    elements
    {
        dataitem(WhseWorksheetLine; "Whse. Worksheet Line")
        {
            column(Worksheet_Template_Name; "Worksheet Template Name") { }
            column(Name; Name) { }
            column(Location_Code; "Location Code") { }
            column(From_Zone_Code; "From Zone Code") { }
            column(To_Zone_Code; "To Zone Code") { }
            column(Item_No_; "Item No.") { }
            column(To_Bin_Code; "To Bin Code") { }
            column(Qty_Base; "Qty. (Base)")
            {
                Method = Sum;
            }
        }
    }
}
