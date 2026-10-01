namespace Kamesons_Customization.Kamesons_Customization;

page 99976 "BULK Load Unit Details List"
{
    PageType = List;
    SourceTable = "BULK Load Unit Details";
    Caption = 'BULK Load Unit Details';
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the entry number.';
                    Visible = false;
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ToolTip = 'Specifies the BULK sales order number.';
                }
                field("Sales Order Line No."; Rec."Sales Order Line No.")
                {
                    ToolTip = 'Specifies the sales order line number.';
                }
                field("Invt. Pick No."; Rec."Invt. Pick No.")
                {
                    ToolTip = 'Specifies the inventory pick this load unit was created for.';
                }
                field("Invt. Pick Line No."; Rec."Invt. Pick Line No.")
                {
                    ToolTip = 'Specifies the line number of the inventory pick line this load unit was created from. When a sales order line is split over several pick lines, this is the first of them.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item number.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ToolTip = 'Specifies the variant code.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the item description.';
                }
                field("Load Unit"; Rec."Load Unit")
                {
                    ToolTip = 'Specifies the load unit for this BULK order line.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the quantity on this load unit.';
                }
                field("Qty. Handled"; Rec."Qty. Handled")
                {
                    ToolTip = 'Specifies the quantity posted in the inventory pick posting this row belongs to.';
                }
                field("Qty. Outstanding"; Rec."Qty. Outstanding")
                {
                    ToolTip = 'Specifies the quantity of the pick line still to be posted after this row''s posting.';
                }
                field("Posted Invt. Pick No."; Rec."Posted Invt. Pick No.")
                {
                    ToolTip = 'Specifies the posted inventory pick this row was handled in.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ToolTip = 'Specifies the unit of measure.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'Specifies the location.';
                }
                field("Dispatch Ramp No."; Rec."Dispatch Ramp No.")
                {
                    ToolTip = 'Specifies the dispatch ramp number of the sales order, sent to Knapp in the Goods Out Order.';
                }
                field("Sent to Knapp"; Rec."Sent to Knapp")
                {
                    ToolTip = 'Specifies whether this line has been sent to Knapp in a Goods Out Order.';
                }
                field("Knapp Queue Entry No."; Rec."Knapp Queue Entry No.")
                {
                    ToolTip = 'Specifies the Knapp Document Queue entry (GO Order) this line was sent with.';
                }
                field("Sent to Knapp DateTime"; Rec."Sent to Knapp DateTime")
                {
                    ToolTip = 'Specifies when this line was sent to Knapp.';
                }
                field("Created By"; Rec."Created By")
                {
                    ToolTip = 'Specifies the user who created the entry.';
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ToolTip = 'Specifies when the entry was created.';
                }
            }
        }
    }
}
