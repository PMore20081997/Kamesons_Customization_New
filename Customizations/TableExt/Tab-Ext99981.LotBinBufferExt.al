namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;

tableextension 99981 Lot_Bin_Buffer_Ext extends "Lot Bin Buffer"
{
    fields
    {
        field(99971; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
            DataClassification = ToBeClassified;
        }
        field(99972; "UOM"; Code[20])
        {
            Caption = 'UOM';
            DataClassification = ToBeClassified;
        }
        field(99973; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = ToBeClassified;
        }
    }
}
