namespace Kamesons_Customization.Kamesons_Customization;

tableextension 99961 MOBWMSRegistrationExt extends "MOB WMS Registration"
{
    fields
    {
        field(99950; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = CustomerContent;
        }
        // Carries the operator-scanned Pallet No. from the put-away device step
        // (id 38) through to posting, where it is written onto the Warehouse
        // Activity Line's "Pallet No." (99973). The registration record is the
        // only thing that survives between the scan and the posting request —
        // SingleInstance state does not.
        field(99951; "Pallet No."; Code[20])
        {
            Caption = 'Pallet No.';
            DataClassification = CustomerContent;
        }
    }
}
