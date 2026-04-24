query 99951 "Released Purchase Orders"
{
    OrderBy = Descending(Order_Date);

    elements
    {
        dataitem(PurchaseLine; 39)
        {
            DataItemTableFilter = Type = CONST(Item);

            filter(No; "No.") { }

            column(Document_No; "Document No.") { }
            column(Line_No; "Line No.") { }
            column(Quantity; Quantity) { }
            column(Direct_Unit_Cost; "Direct Unit Cost") { }

            dataitem(PurchaseHeader; 38)
            {
                DataItemLink = "No." = PurchaseLine."Document No.";
                DataItemTableFilter = Status = CONST(Released);

                column(Order_Date; "Order Date") { }
                column(Vendor_Name; "Buy-from Vendor Name") { }
            }
        }
    }
}