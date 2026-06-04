pageextension 99974 BinContentExt extends "Bin Contents"
{
    layout
    {
        // Lock Max. Qty. to 0 / non-editable when the row's bin is Flowrack —
        // Flowrack capacity is driven by tote count, not by base-unit Max Qty.
        // Field is auto-coerced to 0 in Cod99976 on insert / modify too.
        // modify("Max. Qty.")
        // {
        //     Editable = MaxQtyEditable;
        // }

        addafter("Max. Qty.")
        {
            field("Number of Totes in a Bin"; Rec."Number of Totes in a Bin")
            {
                ApplicationArea = All;
                Caption = 'Number of Totes in a Bin';
                ToolTip = 'Specifies the value of the Number of Totes in a Bin field.';
            }
            field(Bulk; Rec.Bulk)
            {
                ApplicationArea = All;
                Caption = 'Bulk';
                Editable = false;
                ToolTip = 'Bulk routing flag mirrored from the Bin.';
            }
            field("Static"; Rec."Static")
            {
                ApplicationArea = All;
                Caption = 'Static';
                Editable = false;
                ToolTip = 'Static routing flag mirrored from the Bin.';
            }
            field(Flowrack; Rec.Flowrack)
            {
                ApplicationArea = All;
                Caption = 'Flow Rack';
                Editable = false;
                ToolTip = 'Flow Rack routing flag mirrored from the Bin.';
            }
            field(HighBay; Rec.HighBay)
            {
                ApplicationArea = All;
                Caption = 'High Bay';
                Editable = false;
                ToolTip = 'High Bay routing flag mirrored from the Bin.';
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        Rec.CalcFields(Flowrack);
        MaxQtyEditable := not Rec.Flowrack;
    end;

    var
        MaxQtyEditable: Boolean;
}
