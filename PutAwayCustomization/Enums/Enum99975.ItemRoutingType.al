namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// US 40488 — How an item should be routed by the Put-Away engine.
/// Replaces the two mutually-exclusive booleans (Item.BULK / Item.Static)
/// with a single field, easier to audit and to extend with future
/// classifications (Fridge, CD, etc.).
/// </summary>
enum 99950 "Item Routing Type NDPP"
{
    Extensible = true;
    Caption = 'Routing Type';

    value(0; "Flowrack")
    {
        Caption = 'Flowrack';
    }
    value(1; "BULK")
    {
        Caption = 'BULK';
    }
    value(2; "Static")
    {
        Caption = 'Static';

    }
}
