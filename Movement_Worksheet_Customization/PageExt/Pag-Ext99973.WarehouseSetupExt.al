pageextension 99973 WarehouseSetupExt extends "Warehouse Setup"
{
    layout
    {
        addlast(General)
        {

            field("MAIN Warehouse"; Rec."MAIN Warehouse")
            {
                ApplicationArea = All;
                Caption = 'MAIN Warehouse';
                ToolTip = 'Specifies the value of the MAIN Warehouse field.';
            }
            field("RECEIVE Warehouse"; Rec."RECEIVE Warehouse")
            {
                ApplicationArea = All;
                Caption = 'RECEIVE Warehouse';
                ToolTip = 'Specifies the value of the RECEIVE Warehouse field.';
            }
        }
    }
}
