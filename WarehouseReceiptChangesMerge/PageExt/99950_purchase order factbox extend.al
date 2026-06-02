pageextension 99950 "purchase order fact box extend" extends "Purchase Line FactBox"
{
    layout
    {

        modify("No.")
        {
            Visible = false;
        }
        modify(Availability)
        {
            Visible = false;
        }
        modify(PurchasePrices)
        {
            Visible = false;
        }
        modify(PurchaseLineDiscounts)
        {
            Visible = false;
        }
        modify(Attachments)
        {
            Visible = false;
        }

        addafter(Availability)
        {
            group(Inventory)
            {
                Caption = 'Inventory';

                field(AvailabilityNew; PurchInfoPaneMgt.CalcAvailability(Rec))
                {
                    Caption = 'Current Stock';
                    ApplicationArea = All;
                }
                field("Stock on order"; CalcStockOnOrder())
                {
                    ApplicationArea = All;
                    Caption = 'Stock on order';
                    DecimalPlaces = 0 : 5;
                }
                field("WH Receipts"; CountWhseReceipts())
                {
                    ApplicationArea = All;
                    Caption = 'WH Receipts';
                    DrillDown = true;
                    ToolTip = 'Number of Warehouse Receipts that contain this Purchase Line. Click to open the Warehouse Receipt card.';

                    trigger OnDrillDown()
                    var
                        WhseRcptLine: Record "Warehouse Receipt Line";
                        WhseRcptHeader: Record "Warehouse Receipt Header";
                        NoFilter: Text;
                    begin
                        WhseRcptLine.SetRange("Source Type", Database::"Purchase Line");
                        WhseRcptLine.SetRange("Source Subtype", Rec."Document Type".AsInteger());
                        WhseRcptLine.SetRange("Source No.", Rec."Document No.");
                        WhseRcptLine.SetRange("Source Line No.", Rec."Line No.");
                        if WhseRcptLine.Findfirst() then
                            //repeat
                            if NoFilter = '' then
                                NoFilter := WhseRcptLine."No.";
                        // else
                        //     if StrPos('|' + NoFilter + '|', '|' + WhseRcptLine."No." + '|') = 0 then
                        //         NoFilter += '|' + WhseRcptLine."No.";
                        //until WhseRcptLine.Next() = 0;

                        if NoFilter = '' then
                            exit;

                        WhseRcptHeader.SetFilter("No.", NoFilter);
                        if WhseRcptHeader.FindFirst() then
                            Page.Run(Page::"Warehouse Receipt", WhseRcptHeader);
                    end;
                }
                field("Weeks cover stock"; 0)
                {
                    ApplicationArea = All;
                    Caption = 'Weeks cover stock';
                }
            }

            group(Pricing)
            {
                Caption = 'Pricing';

                field("DT Category"; DT_Category)
                {
                    ApplicationArea = All;
                    Caption = 'DT Category';
                }
                field("DT Basic Price"; DT_Basic_Price)
                {
                    ApplicationArea = All;
                    Caption = 'DT Basic Price';
                }
                field("NHS/DM&D Price"; NHS_DM_D_Price)
                {
                    ApplicationArea = All;
                    Caption = 'NHS/DM&D Price';
                }
                field("Retail Price"; Retail_Price)
                {
                    ApplicationArea = All;
                    Caption = 'Retail Price';
                }
                field("RRP"; RRP)
                {
                    ApplicationArea = All;
                    Caption = 'RRP';
                }
                field("Cencora Net Price"; Cencora_Net_Price)
                {
                    ApplicationArea = All;
                    Caption = 'Cencora Net Price';
                }
                field("Phoenix Net Price"; Phoenix_Net_Price)
                {
                    ApplicationArea = All;
                    Caption = 'Phoenix Net Price';
                }

            }
            group(Forecast)
            {
                Caption = 'Forecast';
            }
            group(DocumentFiles)
            {
                Caption = 'Document Files';
            }
            group(VendorStatstics)
            {
                Caption = 'Vendor Statistics';
            }
            group(CoPilotAnalysisOn)
            {
                Caption = 'Co-Pilot Analysis On';
            }
        }

    }
    var
        DT_Category: Text;
        DT_Basic_Price: Text;
        NHS_DM_D_Price: Text;
        Retail_Price: Text;
        RRP: Text;
        Cencora_Net_Price: Text;
        Phoenix_Net_Price: Text;

    trigger OnAfterGetRecord()
    var
        item: Record Item;
    begin
        item.Reset();
        item.SetRange("No.", Rec."No.");
        if item.FindFirst() then begin
            DT_Category := '?';//item.DTCategory;
            DT_Basic_Price := '?';//item.DTBasicPrice;
            NHS_DM_D_Price := '?';//item."NHSDM&DPrice";
            Retail_Price := '?';//item.RetailPrice;
            RRP := '?';// Format(item.RRP);
            Cencora_Net_Price := '?'; //item.CencoraNetPrice;
            Phoenix_Net_Price := '?';// item.PhoenixNetPrice;
        end;
    end;

    protected procedure CalcStockOnOrder(): Decimal
    var
        purchaseLine: Record "Purchase Line";
        qtyOnOrder: Decimal;
    begin
        purchaseLine.Reset();
        purchaseLine.SetRange("No.", Rec."No.");
        if purchaseLine.FindSet() then
            repeat
                qtyOnOrder += purchaseLine.Quantity;
            until purchaseLine.Next() = 0;

        exit(qtyOnOrder);
    end;

    /// <summary>
    /// Count of distinct Warehouse Receipt Headers that have at least one line
    /// pointing at this Purchase Line. Used for the drill-downable "WH Receipts"
    /// field — a Purchase Line can sit on multiple split receipts.
    /// </summary>
    local procedure CountWhseReceipts(): Integer
    var
        WhseRcptLine: Record "Warehouse Receipt Line";
        Headers: List of [Code[20]];
    begin
        WhseRcptLine.SetRange("Source Type", Database::"Purchase Line");
        WhseRcptLine.SetRange("Source Subtype", Rec."Document Type".AsInteger());
        WhseRcptLine.SetRange("Source No.", Rec."Document No.");
        WhseRcptLine.SetRange("Source Line No.", Rec."Line No.");
        if WhseRcptLine.FindSet() then
            repeat
                if not Headers.Contains(WhseRcptLine."No.") then
                    Headers.Add(WhseRcptLine."No.");
            until WhseRcptLine.Next() = 0;
        exit(Headers.Count);
    end;
}