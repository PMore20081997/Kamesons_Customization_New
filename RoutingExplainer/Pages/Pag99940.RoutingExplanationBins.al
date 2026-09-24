namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// "The Numbers Behind It" sub-part of page 99941. One row per bin the
/// explanation considered, with the figures that drove the decision.
///
/// Shown so a supervisor can check the reasoning rather than take it on
/// trust: if the explanation says the face was full, this grid shows the
/// on-hand and maximum it was comparing.
/// </summary>
page 99940 "Routing Explanation Bins NDPP"
{
    Caption = 'Bins';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "Routing Explanation NDPP";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Bins)
            {
                field("Fact Location Code"; Rec."Fact Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location of this bin.';
                }
                field("Fact Bin Code"; Rec."Fact Bin Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the bin.';
                }
                field("Bin Role"; Rec."Bin Role")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies what this bin is used for in the process being explained.';
                }
                field("Qty On Hand"; Rec."Qty On Hand")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how much of the item is currently in this bin.';
                }
                field("Qty In Flight"; Rec."Qty In Flight")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies quantity already committed to this bin on put-away lines that have not been registered yet.';
                }
                field("Min Qty"; Rec."Min Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the minimum quantity set up for the item in this bin. Below this, the bin is topped up.';
                }
                field("Max Qty"; Rec."Max Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum quantity set up for the item in this bin. Stock above this goes elsewhere.';
                }
                field("Empty Totes"; Rec."Empty Totes")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many empty totes this bin has. A partly filled tote still counts as occupied.';
                }
                field("Qty Per Tote"; Rec."Qty Per Tote")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how much of the item fits in one tote.';
                }
                field("Earliest Expiry"; Rec."Earliest Expiry")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the oldest expiry date held in this bin.';
                }
                field("Latest Expiry"; Rec."Latest Expiry")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the newest expiry date held in this bin.';
                }
            }
        }
    }

    /// <summary>
    /// Loads the rows the parent page gathered. Called after every Explain.
    /// </summary>
    procedure SetRows(var SourceBuffer: Record "Routing Explanation NDPP" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if SourceBuffer.FindSet() then
            repeat
                Rec := SourceBuffer;
                Rec.Insert();
            until SourceBuffer.Next() = 0;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;
}
