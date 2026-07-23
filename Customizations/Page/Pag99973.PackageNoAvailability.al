namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;

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
                field("Available Qty. (Base)"; Rec."Available Qty. (Base)")
                {
                    ApplicationArea = All;
                    Caption = 'Available Qty.';
                    ToolTip = 'On-hand qty minus any qty already allocated on outstanding outbound Warehouse Activity Lines (Pick, Movement, etc. — Action Type = Take) for the same Item / Location / Bin / Lot / Package / UOM.';
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
                field("Manufacturer Name"; Rec."Manufacturer Name")
                {
                    ApplicationArea = All;
                    Caption = 'Manufacturer Name';
                    Editable = false;
                    ToolTip = 'Specifies the name of the manufacturer for the Manufacturer Code.';
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
            Rec."Manufacturer Name" := CopyStr(G_TaskletCodeunits.GetManufacturerName(Rec."Manufacturer Code"), 1, MaxStrLen(Rec."Manufacturer Name"));
            Rec."Qty. (Base)" := L_WarehouseEntry.Qty_Base;
            Rec."Expiration Date" := L_WarehouseEntry.Expiration_Date;
            Rec."Available Qty. (Base)" := Rec."Qty. (Base)" - GetCommittedBaseQty(
                Rec."Location Code", Rec."Item No.", Rec."Variant Code",
                Rec."Lot No.", Rec."Package No.");
            Rec.Insert();
        end;
        L_WarehouseEntry.Close();
    end;

    /// <summary>
    /// Sum of outbound qty committed against this exact Item / Location / Lot /
    /// Package / Variant via Reservation Entries. Covers every outbound source
    /// type (Sales Line, Transfer Line, Service Line, Job Planning Line,
    /// Production / Assembly Component, etc.) — Reservation Entry is the
    /// single lot/package-aware commitment store in BC.
    ///
    /// Model A trade-off (intentional): if a non-tracked Sales Order has had a
    /// pick created where the picker assigned a specific Lot/Package at pick
    /// time, no Reservation Entry exists for it and this row will not be
    /// deducted. Acceptable when item tracking is enforced on every outbound
    /// document before picks are created (typical lot-controlled workflow).
    /// If non-tracked-sale picks against specific lots become common, switch
    /// to Model C (dedupe between Reservation Entry and Warehouse Activity
    /// Line by Source Sales Line keys).
    /// </summary>
    local procedure GetCommittedBaseQty(LocationCode: Code[10]; ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]; PackageNo: Code[50]): Decimal
    var
        L_ReservEntry: Record "Reservation Entry";
    begin
        L_ReservEntry.SetRange("Item No.", ItemNo);
        L_ReservEntry.SetRange("Variant Code", VariantCode);
        L_ReservEntry.SetRange("Location Code", LocationCode);
        L_ReservEntry.SetRange("Lot No.", LotNo);
        L_ReservEntry.SetRange("Package No.", PackageNo);
        L_ReservEntry.SetFilter("Reservation Status", '%1|%2',
            L_ReservEntry."Reservation Status"::Reservation,
            L_ReservEntry."Reservation Status"::Tracking);
        L_ReservEntry.SetFilter("Quantity (Base)", '<%1', 0); // demand side only
        L_ReservEntry.CalcSums("Quantity (Base)");
        exit(-L_ReservEntry."Quantity (Base)");
    end;

    var
        G_ItemNoFilter: Code[20];
        G_PackageNoFilter: Code[50];
        G_LocationFilter: Code[10];
        G_TaskletCodeunits: Codeunit Tasklet_Codeunits;
}
