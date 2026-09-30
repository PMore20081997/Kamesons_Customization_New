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
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ToolTip = 'Specifies the unit of measure.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'Specifies the location.';
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
