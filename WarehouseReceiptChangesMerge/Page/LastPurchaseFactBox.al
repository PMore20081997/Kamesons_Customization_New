page 99951 "Purchase Order History"
{
    PageType = CardPart;
    SourceTable = "Purchase Line";
    Caption = 'Last 10 Released POs';
    Editable = false;

    layout
    {
        area(content)
        {
            group("Last 10 Purchase Orders")
            {
                grid(History)
                {
                    GridLayout = Columns;

                    group("PO No")
                    {
                        field(PONo1; PONo1)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo1) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo2; PONo2)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo2) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo3; PONo3)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo3) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo4; PONo4)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo4) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo5; PONo5)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo5) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo6; PONo6)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo6) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo7; PONo7)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo7) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo8; PONo8)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo8) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo9; PONo9)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo9) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                        field(PONo10; PONo10)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            trigger OnDrillDown()
                            var
                                PurchHeader: Record "Purchase Header";
                            begin
                                if PurchHeader.Get(PurchHeader."Document Type"::Order, PONo10) then
                                    PAGE.Run(PAGE::"Purchase Order", PurchHeader);
                            end;
                        }
                    }

                    group("Order Date")
                    {
                        field(OrderDate1; OrderDate1) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate2; OrderDate2) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate3; OrderDate3) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate4; OrderDate4) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate5; OrderDate5) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate6; OrderDate6) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate7; OrderDate7) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate8; OrderDate8) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate9; OrderDate9) { ApplicationArea = All; ShowCaption = false; }
                        field(OrderDate10; OrderDate10) { ApplicationArea = All; ShowCaption = false; }
                    }

                    group("Vendor")
                    {
                        field(Vendor1; Vendor1) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor2; Vendor2) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor3; Vendor3) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor4; Vendor4) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor5; Vendor5) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor6; Vendor6) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor7; Vendor7) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor8; Vendor8) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor9; Vendor9) { ApplicationArea = All; ShowCaption = false; }
                        field(Vendor10; Vendor10) { ApplicationArea = All; ShowCaption = false; }
                    }

                    group("Price")
                    {
                        field(Price1; Price1) { ApplicationArea = All; ShowCaption = false; }
                        field(Price2; Price2) { ApplicationArea = All; ShowCaption = false; }
                        field(Price3; Price3) { ApplicationArea = All; ShowCaption = false; }
                        field(Price4; Price4) { ApplicationArea = All; ShowCaption = false; }
                        field(Price5; Price5) { ApplicationArea = All; ShowCaption = false; }
                        field(Price6; Price6) { ApplicationArea = All; ShowCaption = false; }
                        field(Price7; Price7) { ApplicationArea = All; ShowCaption = false; }
                        field(Price8; Price8) { ApplicationArea = All; ShowCaption = false; }
                        field(Price9; Price9) { ApplicationArea = All; ShowCaption = false; }
                        field(Price10; Price10) { ApplicationArea = All; ShowCaption = false; }
                    }

                    group("Qty")
                    {
                        field(Qty1; Qty1) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty2; Qty2) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty3; Qty3) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty4; Qty4) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty5; Qty5) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty6; Qty6) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty7; Qty7) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty8; Qty8) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty9; Qty9) { ApplicationArea = All; ShowCaption = false; }
                        field(Qty10; Qty10) { ApplicationArea = All; ShowCaption = false; }
                    }
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FillPOHistory();
    end;

    var
        POHistory: Query "Released Purchase Orders";
        i: Integer;

        PONo1, PONo2, PONo3, PONo4, PONo5, PONo6, PONo7, PONo8, PONo9, PONo10 : Code[20];
        OrderDate1, OrderDate2, OrderDate3, OrderDate4, OrderDate5,
        OrderDate6, OrderDate7, OrderDate8, OrderDate9, OrderDate10 : Text;
        Vendor1, Vendor2, Vendor3, Vendor4, Vendor5, Vendor6, Vendor7, Vendor8, Vendor9, Vendor10 : Text;
        Price1, Price2, Price3, Price4, Price5, Price6, Price7, Price8, Price9, Price10 : Text;
        Qty1, Qty2, Qty3, Qty4, Qty5, Qty6, Qty7, Qty8, Qty9, Qty10 : Text;

    local procedure FillPOHistory()
    begin
        Clear(PONo1);
        Clear(PONo2);
        Clear(PONo3);
        Clear(PONo4);
        Clear(PONo5);
        Clear(PONo6);
        Clear(PONo7);
        Clear(PONo8);
        Clear(PONo9);
        Clear(PONo10);
        Clear(OrderDate1);
        Clear(OrderDate2);
        Clear(OrderDate3);
        Clear(OrderDate4);
        Clear(OrderDate5);
        Clear(OrderDate6);
        Clear(OrderDate7);
        Clear(OrderDate8);
        Clear(OrderDate9);
        Clear(OrderDate10);
        Clear(Vendor1);
        Clear(Vendor2);
        Clear(Vendor3);
        Clear(Vendor4);
        Clear(Vendor5);
        Clear(Vendor6);
        Clear(Vendor7);
        Clear(Vendor8);
        Clear(Vendor9);
        Clear(Vendor10);
        Clear(Price1);
        Clear(Price2);
        Clear(Price3);
        Clear(Price4);
        Clear(Price5);
        Clear(Price6);
        Clear(Price7);
        Clear(Price8);
        Clear(Price9);
        Clear(Price10);
        Clear(Qty1);
        Clear(Qty2);
        Clear(Qty3);
        Clear(Qty4);
        Clear(Qty5);
        Clear(Qty6);
        Clear(Qty7);
        Clear(Qty8);
        Clear(Qty9);
        Clear(Qty10);


        POHistory.SetRange(POHistory.No, Rec."No.");
        POHistory.Open();

        i := 0;

        while POHistory.Read() do begin
            i += 1;

            case i of
                1:
                    begin
                        PONo1 := POHistory.Document_No;
                        OrderDate1 := Format(POHistory.Order_Date);
                        Vendor1 := POHistory.Vendor_Name;
                        Price1 := Format(POHistory.Direct_Unit_Cost);
                        Qty1 := Format(POHistory.Quantity);
                    end;
                2:
                    begin
                        PONo2 := POHistory.Document_No;
                        OrderDate2 := Format(POHistory.Order_Date);
                        Vendor2 := POHistory.Vendor_Name;
                        Price2 := Format(POHistory.Direct_Unit_Cost);
                        Qty2 := Format(POHistory.Quantity);
                    end;
            end;

            if i = 10 then
                exit;
        end;

        POHistory.Close();
    end;
}