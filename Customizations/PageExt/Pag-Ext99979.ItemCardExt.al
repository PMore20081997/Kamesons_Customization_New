namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

pageextension 99979 Item_Card_Ext extends "Item Card"
{
    layout
    {
        // "Routing Type" removed from the Item Card. An item's routing types are
        // now derived from the Main-WH bins it holds Bin Content in, and an item
        // may have several at once, so there is nothing single-valued to show
        // here. Use the item's Bin Contents (Bulk / Static / Flowrack flags on
        // the bin) to see and change how it is routed.
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
