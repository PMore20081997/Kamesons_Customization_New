pageextension 99974 BinContentExt extends "Bin Contents"
{
    layout
    {
        addafter("Max. Qty.")
        {
            field("Number of Totes in a Bin"; Rec."Number of Totes in a Bin")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Number of Totes in a Bin field.', Comment = '%';
            }
        }
    }
}
