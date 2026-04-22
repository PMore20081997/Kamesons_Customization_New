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
            }
        }
    }

    trigger OnFindRecord(Which: Text): Boolean
    begin
        FillTempTable;
        EXIT(Rec.FIND(Which));
    end;

    local procedure FillTempTable()
    var
        L_Item: Record Item;
        L_WarehouseEntryReceive: Query WarehouseEntryReceive;
    begin
        Rec.DELETEALL;
        if L_Item.Get(Rec.GETRANGEMIN("Item No.")) then begin
            L_WarehouseEntryReceive.SETRANGE(L_WarehouseEntryReceive.Item_No_, L_Item."No.");
            L_WarehouseEntryReceive.SetFilter(L_WarehouseEntryReceive.Expiration_Date, '>=%1', WorkDate());
            L_WarehouseEntryReceive.SetRange(L_WarehouseEntryReceive.Unit_of_Measure_Code, L_Item."Base Unit of Measure");
            L_WarehouseEntryReceive.SetFilter(L_WarehouseEntryReceive.Qty_Base, '>%1', 0);
            L_WarehouseEntryReceive.OPEN;
            If L_WarehouseEntryReceive.READ then BEGIN
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
                Rec.INSERT;
            END;
            L_WarehouseEntryReceive.Close();
        end;
    end;

}
