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
        addlast(content)
        {
            group(PutAwayRouting)
            {
                Caption = 'Put-Away Routing';

                field("Routing Priority 1"; Rec."Routing Priority 1")
                {
                    ApplicationArea = All;
                    Caption = 'Routing Priority 1';
                    ToolTip = 'Specifies which type of bin a receipt fills first. An item''s routing types come from the main-warehouse bins it is assigned to, and an item may have more than one, so a receipt is filled in this order: each type takes what its face can hold, and only the remainder goes to High Bay. Leave all three blank to use BULK, then Static, then Flowrack.';
                }
                field("Routing Priority 2"; Rec."Routing Priority 2")
                {
                    ApplicationArea = All;
                    Caption = 'Routing Priority 2';
                    ToolTip = 'Specifies which type of bin a receipt fills second, once the first type''s face is full.';
                }
                field("Routing Priority 3"; Rec."Routing Priority 3")
                {
                    ApplicationArea = All;
                    Caption = 'Routing Priority 3';
                    ToolTip = 'Specifies which type of bin a receipt fills last, before any remainder goes to High Bay.';
                }
            }
        }
    }
}
