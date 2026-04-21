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
            DataClassification = ToBeClassified;
        }
    }
}
