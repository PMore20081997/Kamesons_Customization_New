tableextension 99991 BinContentExt extends "Bin Content"
{
    fields
    {
        // field(50000; "Daily Priority Exist"; Boolean)
        // {
        //     FieldClass = FlowField;
        //     CalcFormula = exist("Item Variant" where("Item No." = field("Item No."), Code = field("Variant Code"), Priority = filter(> 0)));
        // }
        // field(50001; "Exclude from free Qty."; Boolean)
        // {
        //     Caption = 'Exclude from free Qty. Calculation';
        //     FieldClass = FlowField; //Prathamesh++ SBB-291
        //     CalcFormula = lookup(Bin."Exclude from free Qty." where(Code = field("Bin Code"), "Location Code" = field("Location Code")));
        //     Editable = false;
        // }
        // field(50002; "Priority From Variant"; Integer)
        // {
        //     FieldClass = FlowField;
        //     CalcFormula = lookup("Item Variant".Priority where("Item No." = field("Item No."), Code = field("Variant Code")));
        //     Editable = false;
        // }
        field(99971; "Number of Totes in a Bin"; Integer)
        {
            DataClassification = CustomerContent;
        }

        // Routing flags mirrored from Bin (see Tab-Ext99956.BinExt.al, fields
        // 99981..99984). FlowField lookups keep Bin Content in sync with the
        // Bin's flag without copy logic; the Bin's OnValidate already enforces
        // at most one flag per bin.
        field(99981; Bulk; Boolean)
        {
            Caption = 'Bulk';
            FieldClass = FlowField;
            CalcFormula = lookup(Bin.Bulk where("Location Code" = field("Location Code"), Code = field("Bin Code")));
            Editable = false;
        }
        field(99982; "Static"; Boolean)
        {
            Caption = 'Static';
            FieldClass = FlowField;
            CalcFormula = lookup(Bin."Static" where("Location Code" = field("Location Code"), Code = field("Bin Code")));
            Editable = false;
        }
        field(99983; Flowrack; Boolean)
        {
            Caption = 'Flow Rack';
            FieldClass = FlowField;
            CalcFormula = lookup(Bin.Flowrack where("Location Code" = field("Location Code"), Code = field("Bin Code")));
            Editable = false;
        }
        field(99984; HighBay; Boolean)
        {
            Caption = 'High Bay';
            FieldClass = FlowField;
            CalcFormula = lookup(Bin.HighBay where("Location Code" = field("Location Code"), Code = field("Bin Code")));
            Editable = false;
        }
    }
}
