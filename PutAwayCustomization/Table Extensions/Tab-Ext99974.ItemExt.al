namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

tableextension 99974 Item_Ext extends Item
{
    fields
    {
        field(99971; "BULK"; Boolean)
        {
            Caption = 'BULK';
            DataClassification = ToBeClassified;
        }
        field(99972; "DTCategory"; Text[10])
        {
            Caption = 'DT Category';
        }
        field(99973; "DTBasicPrice"; Text[10])
        {
            Caption = 'DT Basic Price';
            // DecimalPlaces = 0 : 5;
        }
        field(99974; "NHSDM&DPrice"; Text[10])
        {
            Caption = 'NHS/DM&D Price';
            //DecimalPlaces = 0 : 5;
        }
        field(99975; "RetailPrice"; Text[10])
        {
            Caption = 'Retail Price';
            // DecimalPlaces = 0 : 5;
        }
        // field(60104; "RRP"; Decimal)
        // {
        //     Caption = 'RRP';
        //     DecimalPlaces = 0 : 5;
        // }
        field(99776; "CencoraNetPrice"; Text[10])
        {
            Caption = 'Cencora Net Price';
            //DecimalPlaces = 0 : 5;
        }
        field(99977; "PhoenixNetPrice"; Text[10])
        {
            Caption = 'Phoenix Net Price';
            //DecimalPlaces = 0 : 5;
        }
    }
}
