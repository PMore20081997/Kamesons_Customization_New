namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

tableextension 99984 WhseActLineExt extends "Warehouse Activity Line"
{
    fields
    {
        field(99971; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = CustomerContent;
        }
        field(99972; Priority; Integer)
        {
            Caption = 'Priority';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
        // US xxxxx — operator-entered physical pallet number on put-away Place
        // lines. At registration this value is auto-relabelled onto the stored
        // stock's Package No. (see codeunit "Pallet Reclass Mgt. NDPP"). Field No.
        // is intentionally the SAME (99973) on "Registered Whse. Activity Line" so
        // standard TransferFields carries it across during registration.
        field(99973; "Pallet No."; Code[20])
        {
            Caption = 'Pallet No.';
            DataClassification = CustomerContent;
        }
    }
}
