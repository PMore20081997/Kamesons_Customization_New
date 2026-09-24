namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// "Recent Activity For This Item" sub-part of page 99941.
///
/// This is what ties the screen back to the question users actually ask.
/// When one receipt was split across two bins, both Place lines appear here
/// next to each other, with their quantities and destination bins - so the
/// user can see the split that prompted the question.
/// </summary>
page 99942 "Routing Explanation Act. NDPP"
{
    Caption = 'Recent Lines';
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
            repeater(Activity)
            {
                field("Activity Date"; Rec."Activity Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date of this line.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the put-away document this line belongs to. Two lines sharing a document number are the two halves of a split.';
                }
                field("Activity Qty"; Rec."Activity Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity on this line.';
                }
                field("Activity Bin Code"; Rec."Activity Bin Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the bin this line places stock into.';
                }
                field("Activity Expiry"; Rec."Activity Expiry")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the expiry date of the stock on this line.';
                }
                field("Activity Description"; Rec."Activity Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source document type.';
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
