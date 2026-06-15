namespace Kamesons_Customization.Kamesons_Customization;

page 99990 "Knapp Tote Info List"
{
    PageType = List;
    SourceTable = "Knapp Tote Information";
    Caption = 'Knapp Tote Information';
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = true;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'The entry number is assigned automatically.';
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the sales order number.';
                }
                field("Sales Order Line No."; Rec."Sales Order Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the sales order line number.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field("Tote No."; Rec."Tote No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Knapp tote number.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity assigned to this tote.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CreateKnappTotePicks)
            {
                Caption = 'Create Inventory Picks';
                ApplicationArea = All;
                Image = CreateInventoryPickup;
                ToolTip = 'Create separate inventory picks per tote for the sales order.';


            }
        }
        area(Promoted)
        {
            actionref(CreateKnappTotePicks_Promoted; CreateKnappTotePicks) { }
        }
    }
}
