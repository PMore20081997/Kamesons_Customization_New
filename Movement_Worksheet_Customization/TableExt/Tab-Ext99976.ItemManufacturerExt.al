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
    }
}
