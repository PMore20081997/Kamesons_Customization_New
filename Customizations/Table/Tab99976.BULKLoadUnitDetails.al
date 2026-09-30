namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Foundation.UOM;
using Microsoft.Warehouse.Activity;

// Load Unit details for BULK Sales Orders ("Knapp Order Type" = BULK).
// Standalone: BULK orders are not tied to the Knapp Order Response.
table 99976 "BULK Load Unit Details"
{
    Caption = 'BULK Load Unit Details';
    DataClassification = CustomerContent;
    LookupPageId = "BULK Load Unit Details List";
    DrillDownPageId = "BULK Load Unit Details List";

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
            TableRelation = "Sales Line"."Line No." where("Document Type" = const(Order), "Document No." = field("Sales Order No."));

            trigger OnValidate()
            var
                L_SalesLine: Record "Sales Line";
            begin
                if "Sales Order Line No." = 0 then
                    exit;
                L_SalesLine.Get(L_SalesLine."Document Type"::Order, "Sales Order No.", "Sales Order Line No.");
                "Item No." := L_SalesLine."No.";
                "Variant Code" := L_SalesLine."Variant Code";
                Description := L_SalesLine.Description;
                "Unit of Measure Code" := L_SalesLine."Unit of Measure Code";
                "Location Code" := L_SalesLine."Location Code";
            end;
        }
        field(4; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
        }
        field(5; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
            TableRelation = "Item Variant".Code where("Item No." = field("Item No."));
        }
        field(6; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(7; "Load Unit"; Code[8])
        {
            Caption = 'Load Unit';
        }
        field(8; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(9; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(10; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location;
        }
        field(11; "Created By"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(12; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
            Editable = false;
        }
        field(13; "Invt. Pick No."; Code[20])
        {
            Caption = 'Invt. Pick No.';
            TableRelation = "Warehouse Activity Header"."No." where(Type = const("Invt. Pick"));
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
        key(BySalesOrderLoadUnit; "Sales Order No.", "Load Unit")
        {
        }
        key(ByInvtPickLine; "Invt. Pick No.", "Sales Order Line No.")
        {
        }
    }

    trigger OnInsert()
    begin
        "Created By" := CopyStr(UserId(), 1, MaxStrLen("Created By"));
        "Created DateTime" := CurrentDateTime();
    end;
}
