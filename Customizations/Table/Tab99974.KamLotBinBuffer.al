namespace Kamesons_Customization.Kamesons_Customization;

table 99974 "Kam Lot Bin Buffer"
{
    Caption = 'Kam Lot Bin Buffer';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(3; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
        }
        field(4; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
        }
        field(5; "Zone Code"; Code[10])
        {
            Caption = 'Zone Code';
        }
        field(6; "Bin Code"; Code[20])
        {
            Caption = 'Bin Code';
        }
        field(7; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
        }
        field(8; "Package No."; Code[50])
        {
            Caption = 'Package No.';
        }
        field(9; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
        }
        field(10; "Expiration Date"; Date)
        {
            Caption = 'Expiration Date';
        }
        field(11; "UOM"; Code[20])
        {
            Caption = 'UOM';
        }
        field(12; "Qty. (Base)"; Decimal)
        {
            Caption = 'Qty. (Base)';
            DecimalPlaces = 0 : 5;
        }
        field(13; "Min. Qty."; Decimal)
        {
            Caption = 'Min. Qty.';
            DecimalPlaces = 0 : 5;
        }
        field(14; "Max. Qty."; Decimal)
        {
            Caption = 'Max. Qty.';
            DecimalPlaces = 0 : 5;
        }
        field(15; "Available Qty. (Base)"; Decimal)
        {
            Caption = 'Available Qty. (Base)';
            DecimalPlaces = 0 : 5;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ExpDate; "Expiration Date")
        {
        }
        key(ItemNo; "Item No.")
        {
        }
    }
}
