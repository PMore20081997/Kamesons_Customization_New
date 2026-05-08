namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

pageextension 99979 Item_Card_Ext extends "Item Card"
{
    layout
    {
        addlast(Item)
        {
            field("Routing Type"; Rec."Routing Type")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies how this item is routed during put-away. Flowrack = neither Bulk nor Static. Switching this value is blocked while stock for this item still sits in the previous type''s bin in the Main Warehouse.';
            }
        }
        addafter(VariantMandatoryDefaultNo)
        {
            field(DTCategory; Rec.DTCategory)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'DT Category';
            }
            field(DTBasicPrice; Rec.DTBasicPrice)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'DTBasicPrice';
            }
            field("NHSDM&DPrice"; Rec."NHSDM&DPrice")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'NHS/DM&D Price';

            }
            field(RetailPrice; Rec."RetailPrice")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Retail Price';

            }
            field(CencoraNetPrice; Rec."CencoraNetPrice")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Cencora Net Price';

            }
            field(PhoenixNetPrice; Rec."PhoenixNetPrice")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Phoenix Net Price';

            }
        }
    }
}
