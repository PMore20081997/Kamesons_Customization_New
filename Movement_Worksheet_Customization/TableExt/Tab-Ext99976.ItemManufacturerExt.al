tableextension 99976 ItemManufacturerExt extends "Item Manufacturer Table"
{
    fields
    {
        field(99971; "Qty per Tote"; Decimal)
        {
            Caption = 'Qty per Tote';
            DataClassification = CustomerContent;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }

        // On-hand qty (base) per Item + Manufacturer Code combination.
        // Populated by the Item Manufacturer Factbox at display time using
        // a Warehouse Entry query aggregation (same pattern as the Bin
        // Content Details factbox), so this is a regular Decimal — not a
        // FlowField — and is only meaningful on the page's temporary buffer.
        field(99972; "Total Qty. (Base)"; Decimal)
        {
            Caption = 'Available Quantity';
            DataClassification = CustomerContent;
            Editable = false;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
    }
}
