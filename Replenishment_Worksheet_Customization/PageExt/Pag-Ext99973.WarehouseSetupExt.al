pageextension 99973 WarehouseSetupExt extends "Warehouse Setup"
{
    layout
    {
        addlast(General)
        {

            field("MAIN Warehouse"; Rec."MAIN Warehouse")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the MAIN Warehouse field.', Comment = '%';
            }
        }
    }
}
