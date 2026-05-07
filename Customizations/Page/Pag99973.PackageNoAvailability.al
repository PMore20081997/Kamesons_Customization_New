namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

page 99973 "Package No. Availability"
{
    ApplicationArea = All;
    Caption = 'Package No. Availability';
    PageType = Worksheet;
    SourceTable = "Kam Lot Bin Buffer";
    SourceTableTemporary = true;
    UsageCategory = Lists;
    //Editable = false;
    SaveValues = false;

    layout
    {
        area(Content)
        {
            group(Options)
            {
                Caption = 'Options';
                field(LocationFilter; G_LocationFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Location Filter';
                    TableRelation = Location.Code;
                    ToolTip = 'Specifies the Location Code to filter availability by. Leave blank to include all locations.';

                    trigger OnValidate()
                    begin
                        FillTempTable(G_ItemNoFilter, G_PackageNoFilter, G_LocationFilter);
                        CurrPage.Update(false);
                    end;
                }
                field(ItemNoFilter; G_ItemNoFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Item No.';
                    TableRelation = Item."No.";
                    ToolTip = 'Specifies the Item No. to filter availability by. Leave blank to include all items.';

                    trigger OnValidate()
                    begin
                        FillTempTable(G_ItemNoFilter, G_PackageNoFilter, G_LocationFilter);
                        CurrPage.Update(false);
                    end;
                }
                field(PackageNoFilter; G_PackageNoFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Package No.';
                    ToolTip = 'Specifies the Package No. to filter availability by. Leave blank to include all packages.';
                    Visible = false;
                    trigger OnValidate()
                    begin
                        FillTempTable(G_ItemNoFilter, G_PackageNoFilter, G_LocationFilter);
                        CurrPage.Update(false);
                    end;
                }
            }

            repeater(General)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item that exists for the package number.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location where the package exists.';
                }
                field("Zone Code"; Rec."Zone Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the zone that is assigned to the bin where the package exists.';
                }
                field("Bin Code"; Rec."Bin Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the bin where the package exists.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant code of the item.';
                }
                field("UOM"; Rec."UOM")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unit of measure code.';
                }
                field("Qty. (Base)"; Rec."Qty. (Base)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many items with the package exist in the bin.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lot number that exists in the bin.';
                }
                field("Package No."; Rec."Package No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the package number associated with the lot.';
                }
                field("Manufacturer Code"; Rec."Manufacturer Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the manufacturer code associated with the lot.';
                }
                field("Expiration Date"; Rec."Expiration Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the expiration date of the lot.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                Image = Refresh;
                ShortCutKey = 'F5';
                ToolTip = 'Reload availability for the entered filters. Shortcut: F5.';

                trigger OnAction()
                begin
                    FillTempTable(G_ItemNoFilter, G_PackageNoFilter, G_LocationFilter);
                    CurrPage.Update(false);
                end;
            }
            action(ClearFilter)
            {
                ApplicationArea = All;
                Caption = 'Clear';
                Image = ClearFilter;
                ToolTip = 'Clear the filters and the result list.';

                trigger OnAction()
                begin
                    G_ItemNoFilter := '';
                    G_PackageNoFilter := '';
                    G_LocationFilter := '';
                    Rec.Reset();
                    Rec.DeleteAll();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(Refresh_Promoted; Refresh) { }
                actionref(ClearFilter_Promoted; ClearFilter) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        FillTempTable(G_ItemNoFilter, G_PackageNoFilter, G_LocationFilter);
    end;

    local procedure FillTempTable(ItemNoToShow: Code[20]; PackageNoToShow: Code[50]; LocationToShow: Code[10])
    var
        L_WarehouseEntry: Query WarehouseEntryByPackage;
        EntryNo: Integer;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if ItemNoToShow <> '' then
            L_WarehouseEntry.SetRange(Item_No_, ItemNoToShow);
        if PackageNoToShow <> '' then
            L_WarehouseEntry.SetRange(Package_No_, PackageNoToShow);
        if LocationToShow <> '' then
            L_WarehouseEntry.SetRange(Location_Code, LocationToShow);
        L_WarehouseEntry.SetFilter(Qty_Base, '>%1', 0);
        L_WarehouseEntry.Open();

        EntryNo := 0;
        while L_WarehouseEntry.Read() do begin
            EntryNo += 1;
            Rec.Init();
            Rec."Entry No." := EntryNo;
            Rec."Item No." := L_WarehouseEntry.Item_No_;
            Rec."Variant Code" := L_WarehouseEntry.Variant_Code;
            Rec.UOM := L_WarehouseEntry.Unit_of_Measure_Code;
            Rec."Location Code" := L_WarehouseEntry.Location_Code;
            Rec."Zone Code" := L_WarehouseEntry.Zone_Code;
            Rec."Bin Code" := L_WarehouseEntry.Bin_Code;
            Rec."Lot No." := L_WarehouseEntry.Lot_No_;
            Rec."Package No." := L_WarehouseEntry.Package_No_;
            Rec."Manufacturer Code" := L_WarehouseEntry.Manufacturer_Code;
            Rec."Qty. (Base)" := L_WarehouseEntry.Qty_Base;
            Rec."Expiration Date" := L_WarehouseEntry.Expiration_Date;
            Rec.Insert();
        end;
        L_WarehouseEntry.Close();
    end;

    var
        G_ItemNoFilter: Code[20];
        G_PackageNoFilter: Code[50];
        G_LocationFilter: Code[10];
}
