namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Structure;

tableextension 99974 Item_Ext extends Item
{
    fields
    {
        /// <summary>
        /// US 40488 — Drives Put-Away routing.
        ///   Flowrack -> Flowrack bin   (was "neither" / GEN DECANT)
        ///   BULK     -> Bulk bin
        ///   Static   -> Static bin
        ///
        /// Switching from one type to another is blocked while stock for this
        /// item still sits in the OLD type's bin in the Main Warehouse —
        /// otherwise the routing engine and the decant face would diverge.
        /// </summary>
        field(99970; "Routing Type"; Enum "Item Routing Type NDPP")
        {
            Caption = 'Routing Type';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if Rec."Routing Type" = xRec."Routing Type" then
                    exit;

                CheckMainWHBinEmpty(xRec."Routing Type");
                SyncLegacyFlags();
            end;
        }
        field(99971; "BULK"; Boolean)
        {
            Caption = 'BULK';
            DataClassification = ToBeClassified;
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by "Routing Type". Auto-synced for backward compatibility — read "Routing Type" instead.';
            ObsoleteTag = 'US40488';
        }
        field(99978; "Static"; Boolean)
        {
            Caption = 'Static';
            DataClassification = ToBeClassified;
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by "Routing Type". Auto-synced for backward compatibility — read "Routing Type" instead.';
            ObsoleteTag = 'US40488';
        }
        field(99972; "DTCategory"; Text[10])
        {
            Caption = 'DT Category';
        }
        field(99973; "DTBasicPrice"; Text[10])
        {
            Caption = 'DT Basic Price';
        }
        field(99974; "NHSDM&DPrice"; Text[10])
        {
            Caption = 'NHS/DM&D Price';
        }
        field(99975; "RetailPrice"; Text[10])
        {
            Caption = 'Retail Price';
        }
        field(99776; "CencoraNetPrice"; Text[10])
        {
            Caption = 'Cencora Net Price';
        }
        field(99977; "PhoenixNetPrice"; Text[10])
        {
            Caption = 'Phoenix Net Price';
        }
    }

    /// <summary>
    /// Errors out if the Main-Warehouse bin matching the OLD routing type
    /// still holds positive on-hand qty for this item.
    /// </summary>
    local procedure CheckMainWHBinEmpty(OldRoutingType: Enum "Item Routing Type NDPP")
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
        MainLocation: Code[20];
        ExistingQty: Decimal;
        OldTypeName: Text;
    begin
        MainLocation := KamWhseSetupLookup.GetMainLocation();

        Bin.SetRange("Location Code", MainLocation);
        case OldRoutingType of
            OldRoutingType::BULK:
                Bin.SetRange(Bulk, true);
            OldRoutingType::"Static":
                Bin.SetRange("Static", true);
            OldRoutingType::Flowrack:
                Bin.SetRange(Flowrack, true);
        end;
        if not Bin.FindFirst() then
            exit; // Old type has no matching bin in Main WH — nothing to check.

        BinContent.SetRange("Location Code", MainLocation);
        BinContent.SetRange("Bin Code", Bin.Code);
        BinContent.SetRange("Item No.", Rec."No.");
        if BinContent.FindSet() then
            repeat
                BinContent.CalcFields("Quantity (Base)");
                ExistingQty += BinContent."Quantity (Base)";
            until BinContent.Next() = 0;

        if ExistingQty > 0 then begin
            OldTypeName := Format(OldRoutingType);
            Error(StockExistsErr, OldTypeName, ExistingQty, MainLocation, Bin.Code);
        end;
    end;

    /// <summary>
    /// Mirrors the new "Routing Type" into the obsolete BULK / Static booleans
    /// so existing callers (Movement Worksheet, Replenishment) keep seeing
    /// the right values until they migrate to "Routing Type".
    /// </summary>
    local procedure SyncLegacyFlags()
    begin
        case Rec."Routing Type" of
            Rec."Routing Type"::BULK:
                begin
                    Rec.BULK := true;
                    Rec."Static" := false;
                end;
            Rec."Routing Type"::"Static":
                begin
                    Rec.BULK := false;
                    Rec."Static" := true;
                end;
            Rec."Routing Type"::Flowrack:
                begin
                    Rec.BULK := false;
                    Rec."Static" := false;
                end;
        end;
    end;

    var
        KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        StockExistsErr: Label 'Cannot change Routing Type. Item still has %2 base qty in the %1 bin (%4) at location %3. Move that stock out before changing the routing type.', Comment = '%1 = old routing type; %2 = qty; %3 = location; %4 = bin code';
}
