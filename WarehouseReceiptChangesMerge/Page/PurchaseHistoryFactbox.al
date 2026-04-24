page 99952 "Purchase History Factbox"
{
    PageType = ListPart;
    SourceTable = "Purch. Rcpt. Line";
    Editable = false;
    Caption = 'Purchase History';

    SourceTableView =
        sorting("No.", "Posting Date")
        order(descending)
        where(Type = const(Item));

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Order No."; Rec."Order No.")
                {
                    ApplicationArea = All;
                    Caption = 'PO No';
                }

                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Caption = 'PO Date';
                }

                field("Buy-from Vendor No."; Rec."Buy-from Vendor No.")
                {
                    ApplicationArea = All;
                    Caption = 'Vendor';
                }

                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                }

                field("Direct Unit Cost"; Rec."Direct Unit Cost")
                {
                    ApplicationArea = All;
                    Caption = 'Price';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange("Posting Date", CalcDate('-5Y', Today), Today);
    end;
}