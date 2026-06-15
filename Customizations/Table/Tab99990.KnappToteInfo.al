namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;
using Microsoft.Inventory.Item;

table 99975 "Knapp Tote Information"
{
    Caption = 'Knapp Tote Information';
    DataClassification = CustomerContent;
    LookupPageId = "Knapp Tote Info List";
    DrillDownPageId = "Knapp Tote Info List";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Sales Order No."; Code[20])
        {
            Caption = 'Sales Order No.';
            TableRelation = "Sales Header"."No." where("Document Type" = const(Order));
        }
        field(3; "Sales Order Line No."; Integer)
        {
            Caption = 'Sales Order Line No.';
        }
        field(4; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
        }
        field(5; "Tote No."; Code[20])
        {
            Caption = 'Tote No.';
        }
        field(6; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(BySalesOrderLine; "Sales Order No.", "Sales Order Line No.")
        {
        }
        key(BySalesOrderTote; "Sales Order No.", "Tote No.")
        {
        }
    }
}
