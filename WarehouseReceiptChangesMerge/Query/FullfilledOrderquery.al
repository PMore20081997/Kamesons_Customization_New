query 99950 "Item Shipment Monthly Qty"
{
    elements
    {
        dataitem(SalesShipmentLine; "Sales Shipment Line")
        {
            column(ItemNo; "No.") { }
            column(PostingDate; "Posting Date") { }

            column(Quantity; Quantity)
            {
                Method = Sum;
            }
        }
    }
}