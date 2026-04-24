page 99950 "Fulfilled orders"
{
    PageType = ListPart;
    SourceTable = "Sales Shipment Line";
    SourceTableTemporary = true;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Month/Year"; MonthYearTxt)
                {
                    ApplicationArea = All;
                }

                field(Quantity; Qty)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    var
        ShipmentQuery: Query "Item Shipment Monthly Qty";
        MonthYearTxt: Text[20];
        Qty: Decimal;

    trigger OnAfterGetRecord()
    begin
        LoadData();
    end;

    local procedure LoadData()
    var
        StartDate: Date;
    begin
        StartDate := CalcDate('-6M', Today);

        ShipmentQuery.SetRange(PostingDate, StartDate, Today);

        if ShipmentQuery.Open() then
            while ShipmentQuery.Read() do begin

                MonthYearTxt :=
                  Format(Date2DMY(ShipmentQuery.PostingDate, 2)) + '/' +
                  Format(Date2DMY(ShipmentQuery.PostingDate, 3));

                Qty := ShipmentQuery.Quantity;

            end;

        ShipmentQuery.Close();
    end;
}