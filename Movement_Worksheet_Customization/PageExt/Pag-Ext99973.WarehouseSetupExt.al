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
            field("Case Label Nos."; Rec."Case Label Nos.")
            {
                ApplicationArea = All;
                Caption = 'Case Label Nos.';
                ToolTip = 'Specifies the number series used to generate the Load Unit (case label) for BULK order inventory picks. Numbers must be at most 8 characters, e.g. 00000001.';
            }
            field("Goods Out Nos."; Rec."Goods Out Nos.")
            {
                ApplicationArea = All;
                Caption = 'Goods Out Nos.';
                ToolTip = 'Specifies the number series used for the order number of Goods Out Orders sent to KNAPP from the Goods Out screen on the mobile device. Numbers must be exactly 8 characters, e.g. 00000001.';
            }
        }
    }
}
