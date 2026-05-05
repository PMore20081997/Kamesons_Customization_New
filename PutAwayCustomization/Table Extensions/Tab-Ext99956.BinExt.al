namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;

tableextension 99956 Bin_Ext extends Bin
{
    fields
    {
        field(99981; "Bulk"; Boolean)
        {
            Caption = 'Bulk';
            DataClassification = ToBeClassified;
        }
        field(99982; "Static"; Boolean)
        {
            DataClassification = ToBeClassified;
            Caption = 'Static';
        }
        field(99983; "Flowrack"; Boolean)
        {
            DataClassification = ToBeClassified;
            Caption = 'Flowrack';
        }
        field(99984; "HighBay"; Boolean)
        {
            Caption = 'High Bay';
            DataClassification = ToBeClassified;
        }
    }
}
