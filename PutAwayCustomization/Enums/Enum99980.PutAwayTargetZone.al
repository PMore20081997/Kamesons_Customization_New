namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// US 40488 — three possible zone classifications a Put-Away line can target
/// at the Receive Warehouse. Replacing the inline `Option BulkDecant,GenDecant,HighBay`
/// from the original Cod99983 with this enum makes it self-documenting,
/// extensible (e.g. for future Fridge/CD zones), and removes the `case 1/2`
/// hard-coded calls that appeared in OnBeforeInsertNewWhseActivLine.
/// </summary>
enum 99980 "Put-Away Target Zone NDPP"
{
    Extensible = true;
    Caption = 'Put-Away Target Zone';

    value(0; "BulkDecant")
    {
        Caption = 'Bulk Decant';
    }
    value(1; "GenDecant")
    {
        Caption = 'General Decant';
    }
    value(2; "HighBay")
    {
        Caption = 'High Bay';
    }
    value(3; "Static")
    {
        Caption = 'Static';
    }
}
