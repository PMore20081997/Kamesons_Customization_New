namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

tableextension 99974 Item_Ext extends Item
{
    fields
    {
        // Field 99970 "Routing Type" removed (US 40488 follow-up).
        //
        // An item's routing types are now DERIVED from the Main-WH bins it holds
        // Bin Content in (the Bulk / Static / Flowrack flags on Bin), through
        // "Kam Whse Setup Lookup".GetItemRoutingTypes / ItemHasRoutingType.
        //
        // WHY: a single enum could hold only ONE value, but an item may
        // genuinely be several types at once - a BULK reserve pallet AND a
        // Flowrack pick face. The field reported only the first, so the other
        // face's capacity was never considered and stock went to High Bay while
        // a valid pick face stood empty.
        //
        // The guard this field carried (no retyping while stock still sits in
        // the old type's bin) is replaced by "Routing Bin Guards NDPP", which
        // blocks removing a routing bin that still holds stock, and blocks
        // assigning one whose Max Qty / Number of Totes is not configured.
        //
        // Fields 99971 "BULK" and 99978 "Static" - the booleans Routing Type
        // itself replaced - were already retired before this change.
        field(99972; "DTCategory"; Text[10])
        {
            Caption = 'DT Category';
        }
        field(99973; "DTBasicPrice"; Text[10])
        {
            Caption = 'DT Basic Price';
        }
        field(99974; "NHSDM&DPrice"; Text[10])
        {
            Caption = 'NHS/DM&D Price';
        }
        field(99975; "RetailPrice"; Text[10])
        {
            Caption = 'Retail Price';
        }
        field(99776; "CencoraNetPrice"; Text[10])
        {
            Caption = 'Cencora Net Price';
        }
        field(99977; "PhoenixNetPrice"; Text[10])
        {
            Caption = 'Phoenix Net Price';
        }
    }
}
