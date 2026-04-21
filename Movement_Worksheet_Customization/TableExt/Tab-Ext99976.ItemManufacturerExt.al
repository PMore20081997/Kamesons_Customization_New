tableextension 99976 ItemManufacturerExt extends "Item Manufacturer Table"
{
    fields
    {
        field(99971; "Qty per Tote"; Decimal)
        {
            DataClassification = ToBeClassified;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
    }
}
