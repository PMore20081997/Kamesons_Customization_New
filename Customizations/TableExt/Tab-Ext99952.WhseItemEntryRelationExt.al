namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Ledger;

tableextension 99952 Whse_Item_Entry_Relation_Ext extends "Whse. Item Entry Relation"
{
    fields
    {
        field(99950; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = CustomerContent;
        }
    }
}
