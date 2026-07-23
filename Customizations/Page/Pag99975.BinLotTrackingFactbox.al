namespace Kamesons_Customization.Kamesons_Customization;

page 99975 "Bin Lot Tracking Factbox"
{
    Caption = 'Lot No. by Item';
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
                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the lot number in the bin.';
                }
                field("Package No."; Rec."Package No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the package number associated with the lot.';
                }
                field("Qty. (Base)"; Rec."Qty. (Base)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity in base units.';
                }
                field("Expiration Date"; Rec."Expiration Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the expiration date of the lot.';
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
        FilterLocationCode: Code[10];
        FilterBinCode: Code[20];
    begin
        GetLinkedFilters(FilterItemNo, FilterLocationCode, FilterBinCode);
        if FilterItemNo = '' then
            exit(false);

        if (FilterItemNo <> G_LastItemNo) or
           (FilterLocationCode <> G_LastLocationCode) or
           (FilterBinCode <> G_LastBinCode) or
           not G_Loaded
        then begin
            FillTempTable(FilterItemNo, FilterLocationCode, FilterBinCode);
            G_LastItemNo := FilterItemNo;
            G_LastLocationCode := FilterLocationCode;
            G_LastBinCode := FilterBinCode;
            G_Loaded := true;
        end;
        exit(Rec.Find(Which));
    end;

    local procedure GetLinkedFilters(var ItemNo: Code[20]; var LocationCode: Code[10]; var BinCode: Code[20])
    var
        PrevFilterGroup: Integer;
    begin
        PrevFilterGroup := Rec.FilterGroup();
        Rec.FilterGroup(4);
        ItemNo := CopyStr(Rec.GetFilter("Item No."), 1, MaxStrLen(ItemNo));
        LocationCode := CopyStr(Rec.GetFilter("Location Code"), 1, MaxStrLen(LocationCode));
        BinCode := CopyStr(Rec.GetFilter("Bin Code"), 1, MaxStrLen(BinCode));
        if ItemNo = '' then begin
            Rec.FilterGroup(2);
            ItemNo := CopyStr(Rec.GetFilter("Item No."), 1, MaxStrLen(ItemNo));
            LocationCode := CopyStr(Rec.GetFilter("Location Code"), 1, MaxStrLen(LocationCode));
            BinCode := CopyStr(Rec.GetFilter("Bin Code"), 1, MaxStrLen(BinCode));
        end;
        Rec.FilterGroup(PrevFilterGroup);
        if ItemNo = '' then
            ItemNo := CopyStr(Rec.GetFilter("Item No."), 1, MaxStrLen(ItemNo));
    end;

    local procedure FillTempTable(ItemNoFilter: Code[20]; LocationCodeFilter: Code[10]; BinCodeFilter: Code[20])
    var
        Q: Query WarehouseEntryByPackage;
        EntryNo: Integer;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if ItemNoFilter = '' then
            exit;

        Q.SetRange(Item_No_, ItemNoFilter);
        if LocationCodeFilter <> '' then
            Q.SetRange(Location_Code, LocationCodeFilter);
        if BinCodeFilter <> '' then
            Q.SetRange(Bin_Code, BinCodeFilter);
        Q.SetFilter(Qty_Base, '>%1', 0);
        Q.Open();

        EntryNo := 0;
        while Q.Read() do begin
            EntryNo += 1;
            Rec.Init();
            Rec."Entry No." := EntryNo;
            Rec."Item No." := Q.Item_No_;
            Rec."Location Code" := Q.Location_Code;
            Rec."Zone Code" := Q.Zone_Code;
            Rec."Bin Code" := Q.Bin_Code;
            Rec."Lot No." := Q.Lot_No_;
            Rec."Package No." := Q.Package_No_;
            Rec."Manufacturer Code" := Q.Manufacturer_Code;
            Rec."Manufacturer Name" := CopyStr(G_TaskletCodeunits.GetManufacturerName(Rec."Manufacturer Code"), 1, MaxStrLen(Rec."Manufacturer Name"));
            Rec."Qty. (Base)" := Q.Qty_Base;
            Rec."Expiration Date" := Q.Expiration_Date;
            Rec.Insert();
        end;
        Q.Close();
    end;

    var
        G_LastItemNo: Code[20];
        G_LastLocationCode: Code[10];
        G_LastBinCode: Code[20];
        G_Loaded: Boolean;
        G_TaskletCodeunits: Codeunit Tasklet_Codeunits;
}
