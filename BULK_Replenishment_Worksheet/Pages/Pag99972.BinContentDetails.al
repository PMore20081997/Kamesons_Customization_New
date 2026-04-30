namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;
using Microsoft.Inventory.Item;

page 99972 "Receive Bin Content Details"
{
    ApplicationArea = All;
    Caption = 'Bin_Content_Details';
    PageType = ListPart;
    SourceTable = "Lot Bin Buffer";
    UsageCategory = Administration;
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(General)
            {

                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item that exists as lot numbers in the bin.';
                    ApplicationArea = All;
                }
                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'Specifies the value of the Location Code field.', Comment = '%';
                    ApplicationArea = All;
                }
                field("Zone Code"; Rec."Zone Code")
                {
                    ToolTip = 'Specifies the zone that is assigned to the bin where the lot number exists.';
                    ApplicationArea = All;
                }
                field("Bin Code"; Rec."Bin Code")
                {
                    ToolTip = 'Specifies the bin where the lot number exists.';
                    ApplicationArea = All;
                }
                field("Qty. (Base)"; Rec."Qty. (Base)")
                {
                    ToolTip = 'Specifies how many items with the lot number exist in the bin.';
                    ApplicationArea = All;
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the lot number that exists in the bin.';
                    ApplicationArea = All;
                }
                field("Expiration Date"; Rec."Expiration Date")
                {
                    ToolTip = 'Specifies the value of the Expiration Date field.', Comment = '%';
                    ApplicationArea = All;
                }
                // field("Min Qty."; Rec."Min. Qty.")
                // {
                //     ApplicationArea = All;
                // }
                // field("Max Qty."; Rec."Max. Qty.")
                // {
                //     ApplicationArea = All;
                // }
            }
        }
    }

    trigger OnFindRecord(Which: Text): Boolean
    begin
        FillTempTable();
        Rec.SetCurrentKey("Expiration Date");
        Rec.Ascending(true);
        exit(Rec.Find(Which));
    end;

    local procedure GetMinQty(_LocationCode: Code[10]; _BinCode: Code[20]; _ItemNo: Code[20]; _VariantCode: Code[10]; _UOM: Code[20]): Decimal
    begin
        G_BinContent.Reset();
        If G_BinContent.Get(_LocationCode, _BinCode, _ItemNo, _VariantCode, _UOM) then begin
            exit(G_BinContent."Min. Qty.");
        end;
    end;

    local procedure GetMaxQty(_LocationCode: Code[10]; _BinCode: Code[20]; _ItemNo: Code[20]; _VariantCode: Code[10]; _UOM: Code[20]): Decimal
    begin
        G_BinContent.Reset();
        If G_BinContent.Get(_LocationCode, _BinCode, _ItemNo, _VariantCode, _UOM) then begin
            exit(G_BinContent."Max. Qty.");
        end;
    end;

    local procedure FillTempTable()
    var
        L_WarehouseEntryReceive: Query WarehouseEntryReceive;
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
    begin
        L_WarehouseEntryReceive.SETRANGE(L_WarehouseEntryReceive.Item_No_, Rec.GetRangeMin("Item No."));
        L_WarehouseEntryReceive.SetRange(L_WarehouseEntryReceive.Location_Code, L_KamWhseSetupLookup.GetReceiveLocation());
        // L_WarehouseEntryReceive.SetRange(L_WarehouseEntryReceive.Zone);
        L_WarehouseEntryReceive.SetFilter(L_WarehouseEntryReceive.Expiration_Date, '>=%1', WorkDate());
        L_WarehouseEntryReceive.SetFilter(L_WarehouseEntryReceive.Qty_Base, '>%1', 0);
        L_WarehouseEntryReceive.OPEN;

        Rec.DELETEALL;

        while L_WarehouseEntryReceive.READ() do BEGIN
            Rec.INIT;
            Rec."Item No." := L_WarehouseEntryReceive.Item_No_;
            Rec.UOM := L_WarehouseEntryReceive.Unit_of_Measure_Code;
            Rec."Location Code" := L_WarehouseEntryReceive.Location_Code;
            Rec."Zone Code" := L_WarehouseEntryReceive.Zone_Code;
            Rec."Bin Code" := L_WarehouseEntryReceive.Bin_Code;
            Rec."Lot No." := L_WarehouseEntryReceive.Lot_No_;
            Rec."Manufacturer Code" := L_WarehouseEntryReceive.Manufacturer_Code;
            Rec."Qty. (Base)" := L_WarehouseEntryReceive.Qty_Base;
            Rec."Expiration Date" := L_WarehouseEntryReceive.Expiration_Date;
            Rec."Min. Qty." := GetMinQty(Rec."Location Code", Rec."Bin Code", Rec."Item No.", Rec."Variant Code", Rec.UOM);
            Rec."Max. Qty." := GetMaxQty(Rec."Location Code", Rec."Bin Code", Rec."Item No.", Rec."Variant Code", Rec.UOM);
            Rec.INSERT;
        END;
        L_WarehouseEntryReceive.Close();
    end;

    var
        G_BinContent: Record "Bin Content";

}
