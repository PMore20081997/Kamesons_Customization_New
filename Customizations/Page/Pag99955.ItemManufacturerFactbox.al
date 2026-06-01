namespace Kamesons_Customization.Kamesons_Customization;

page 99955 "Item Manufacturer Factbox"
{
    Caption = 'Item Manufacturer Factbox';
    PageType = ListPart;
    SourceTable = "Item Manufacturer Table";
    SourceTableTemporary = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Item No"; Rec."Item No")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field("Manufacturer code"; Rec."Manufacturer code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the manufacturer code (Manufacturer Code field from C&D).';
                }
                field("Manufacturer Name"; Rec."Manufacturer Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the manufacturer name (from C&D).';
                }
                // field("Qty per Tote"; Rec."Qty per Tote")
                // {
                //     ApplicationArea = All;
                //     ToolTip = 'Specifies the maximum quantity per tote.';
                // }
                field("MainWH Available Qty"; Rec."MainWH Available Qty")
                {
                    ApplicationArea = All;
                    Caption = 'MainWH Available Qty';
                    ToolTip = 'Net on-hand stock at the Main Warehouse location for this Item / Manufacturer Code (positives minus shipments).';
                }
                field("GoodsIn Available Qty"; Rec."GoodsIn Available Qty")
                {
                    ApplicationArea = All;
                    Caption = 'GoodsIn Available Qty';
                    ToolTip = 'Net on-hand stock at the Goods-In (Receive) location for this Item / Manufacturer Code (positives minus shipments).';
                }
            }
        }
    }

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

    /// <summary>
    /// Reads the Item No. filter the host page pushes into the factbox via
    /// SubPageLink. Mirrors Pag99972 — walks FilterGroup 4 (extended), then 2
    /// (subpage), then the default.
    /// </summary>
    local procedure GetLinkedItemNo() ItemNo: Code[20]
    var
        PrevFilterGroup: Integer;
    begin
        PrevFilterGroup := Rec.FilterGroup();
        Rec.FilterGroup(4);
        ItemNo := CopyStr(Rec.GetFilter("Item No"), 1, MaxStrLen(ItemNo));
        if ItemNo = '' then begin
            Rec.FilterGroup(2);
            ItemNo := CopyStr(Rec.GetFilter("Item No"), 1, MaxStrLen(ItemNo));
        end;
        Rec.FilterGroup(PrevFilterGroup);
        if ItemNo = '' then
            ItemNo := CopyStr(Rec.GetFilter("Item No"), 1, MaxStrLen(ItemNo));
    end;

    /// <summary>
    /// Aggregates Warehouse Entry rows by Manufacturer Code for the given Item,
    /// bucketed by location: Main Warehouse vs. Goods-In (Receive) — every
    /// other location is ignored. Re-uses the WarehouseEntryReceive query
    /// (same source as the Bin Content Details factbox). Net qty per location
    /// is the sum of positive receives and negative shipments.
    /// </summary>
    local procedure FillTempTable(ItemNoToShow: Code[20])
    var
        L_WarehouseEntryReceive: Query WarehouseEntryReceive;
        L_PersistedItemMfr: Record "Item Manufacturer Table";
        L_MainLocation: Code[20];
        L_ReceiveLocation: Code[20];
    begin
        Rec.Reset();
        Rec.DeleteAll();

        if ItemNoToShow = '' then
            exit;

        L_MainLocation := G_KamWhseSetupLookup.GetMainLocation();
        L_ReceiveLocation := G_KamWhseSetupLookup.GetReceiveLocation();

        L_WarehouseEntryReceive.SetRange(Item_No_, ItemNoToShow);
        L_WarehouseEntryReceive.SetFilter(Manufacturer_Code, '<>%1', '');
        L_WarehouseEntryReceive.Open();

        while L_WarehouseEntryReceive.Read() do begin
            // Skip locations that are neither Main nor Goods-In.
            if (L_WarehouseEntryReceive.Location_Code <> L_MainLocation) and
               (L_WarehouseEntryReceive.Location_Code <> L_ReceiveLocation)
            then
                continue;

            if not Rec.Get(L_WarehouseEntryReceive.Item_No_, L_WarehouseEntryReceive.Manufacturer_Code) then begin
                Rec.Init();
                Rec."Item No" := L_WarehouseEntryReceive.Item_No_;
                Rec."Manufacturer code" := L_WarehouseEntryReceive.Manufacturer_Code;
                if L_PersistedItemMfr.Get(L_WarehouseEntryReceive.Item_No_, L_WarehouseEntryReceive.Manufacturer_Code) then begin
                    Rec."Manufacturer Name" := L_PersistedItemMfr."Manufacturer Name";
                    Rec."Qty per Tote" := L_PersistedItemMfr."Qty per Tote";
                end;
                Rec.Insert();
            end;

            if L_WarehouseEntryReceive.Location_Code = L_MainLocation then
                Rec."MainWH Available Qty" += L_WarehouseEntryReceive.Qty_Base
            else
                Rec."GoodsIn Available Qty" += L_WarehouseEntryReceive.Qty_Base;
            Rec.Modify();
        end;
        L_WarehouseEntryReceive.Close();
    end;

    var
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        G_LastItemNo: Code[20];
        G_Loaded: Boolean;
}
