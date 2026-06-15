namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Activity;

tableextension 99990 WhseActivityHeaderToteExt extends "Warehouse Activity Header"
{
    fields
    {
        field(50000; "Tote No. NDPP"; Code[20])
        {
            Caption = 'Tote No.';
            DataClassification = CustomerContent;
        }
    }
}
