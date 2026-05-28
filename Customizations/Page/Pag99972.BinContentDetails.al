namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;

page 99972 "Bin Content Details"
{
    Caption = 'Bin Content Details';
    PageType = ListPart;
    SourceTable = "Kam Lot Bin Buffer";
    SourceTableTemporary = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item that exists as lot numbers in the bin.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the location where the lot exists.';
                }
                field("Zone Code"; Rec."Zone Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the zone that is assigned to the bin where the lot number exists.';
                }
                field("Bin Code"; Rec."Bin Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the bin where the lot number exists.';
                }
                field("Qty. (Base)"; Rec."Qty. (Base)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies how many items with the lot number exist in the bin.';
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

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey("Expiration Date");
        Rec.Ascending(true);
    end;

    trigger OnFindRecord(Which: Text): Boolean
    var
        FilterItemNo: Code[20];
    begin
        FilterItemNo := GetLinkedItemNo();
        if FilterItemNo = '' then
            exit(false);

        if (FilterItemNo <> G_LastItemNo) or (not G_Loaded) then begin
            FillTempTable(FilterItemNo);
            G_LastItemNo := FilterItemNo;
            G_Loaded := true;
        end;
        exit(Rec.Find(Which));
    end;

    local procedure GetLinkedItemNo() ItemNo: Code[20]
    var
        PrevFilterGroup: Integer;
    begin
        PrevFilterGroup := Rec.FilterGroup();
        Rec.FilterGroup(4);
        ItemNo := CopyStr(Rec.GetFilter("Item No."), 1, MaxStrLen(ItemNo));
        if ItemNo = '' then begin
            Rec.FilterGroup(2);
            ItemNo := CopyStr(Rec.GetFilter("Item No."), 1, MaxStrLen(ItemNo));
        end;
        Rec.FilterGroup(PrevFilterGroup);
        if ItemNo = '' then
            ItemNo := CopyStr(Rec.GetFilter("Item No."), 1, MaxStrLen(ItemNo));
    end;

    local procedure FillTempTable(ItemNoToShow: Code[20])
    var
        L_WarehouseEntryReceive: Query WarehouseEntryReceive;
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        EntryNo: Integer;
        Min: Decimal;
        Max: Decimal;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if ItemNoToShow = '' then
            exit;

        L_WarehouseEntryReceive.SetRange(Item_No_, ItemNoToShow);
        //L_WarehouseEntryReceive.SetRange(Location_Code, L_KamWhseSetupLookup.GetReceiveLocation());
        L_WarehouseEntryReceive.SetFilter(Expiration_Date, '>=%1', WorkDate());
        L_WarehouseEntryReceive.SetFilter(Qty_Base, '>%1', 0);
        L_WarehouseEntryReceive.Open();

        EntryNo := 0;
        while L_WarehouseEntryReceive.Read() do begin
            EntryNo += 1;
            Rec.Init();
            Rec."Entry No." := EntryNo;
            Rec."Item No." := L_WarehouseEntryReceive.Item_No_;
            Rec."Variant Code" := L_WarehouseEntryReceive.Variant_Code;
            Rec.UOM := L_WarehouseEntryReceive.Unit_of_Measure_Code;
            Rec."Location Code" := L_WarehouseEntryReceive.Location_Code;
            Rec."Zone Code" := L_WarehouseEntryReceive.Zone_Code;
            Rec."Bin Code" := L_WarehouseEntryReceive.Bin_Code;
            Rec."Lot No." := L_WarehouseEntryReceive.Lot_No_;
            Rec."Package No." := L_WarehouseEntryReceive.Package_No_;
            Rec."Manufacturer Code" := L_WarehouseEntryReceive.Manufacturer_Code;
            Rec."Qty. (Base)" := L_WarehouseEntryReceive.Qty_Base;
            Rec."Expiration Date" := L_WarehouseEntryReceive.Expiration_Date;
            GetMinMaxQty(Rec."Location Code", Rec."Bin Code", Rec."Item No.", Rec."Variant Code", Rec.UOM, Min, Max);
            Rec."Min. Qty." := Min;
            Rec."Max. Qty." := Max;
            Rec.Insert();
        end;
        L_WarehouseEntryReceive.Close();
    end;

    local procedure GetMinMaxQty(LocCode: Code[10]; BinCode: Code[20]; ItemNo: Code[20]; VariantCode: Code[10]; UOM: Code[20]; var Min: Decimal; var Max: Decimal)
    var
        BinContent: Record "Bin Content";
    begin
        Min := 0;
        Max := 0;
        if BinContent.Get(LocCode, BinCode, ItemNo, VariantCode, UOM) then begin
            Min := BinContent."Min. Qty.";
            Max := BinContent."Max. Qty.";
        end;
    end;

    var
        G_LastItemNo: Code[20];
        G_Loaded: Boolean;
}
