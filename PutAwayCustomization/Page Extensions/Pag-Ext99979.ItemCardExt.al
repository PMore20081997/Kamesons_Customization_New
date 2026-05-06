namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

pageextension 99979 Item_Card_Ext extends "Item Card"
{
    layout
    {
        addlast(Item)
        {
            field(BULK; Rec.BULK)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the BULK field.', Comment = '%';
            }
            field("Static"; Rec."Static")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether this item should be put away to the Static bin at the Receive Location.';
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
