pageextension 99993 SalesAndRecSetupExt extends "Sales & Receivables Setup"
{
    layout
    {
        addlast(General)
        {
            field("Hub Sales Margin %"; Rec."Hub Sales Margin %")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the margin applied on top of Unit Cost (LCY) to calculate the Unit Price on sales lines posted from a Hub location with a value on the Branches dimension.';
            }
        }
    }
}
