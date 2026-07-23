Report 99971 "Cal _Bin Replenishment New"
{
    Caption = 'Calculate Bin Replenishment';
    ProcessingOnly = true;

    dataset
    {
        dataitem(Item; Item)
        {
            DataItemTableView = sorting("No.") order(descending);
            RequestFilterFields = "No.";

            trigger OnAfterGetRecord()
            begin
                FindEmptyTotesAndCreateRepWorksheet("No.", LocationCode);
            end;

            trigger OnPreDataItem()
            begin
                Item.SetFilter("Routing Type", '%1', "Item Routing Type NDPP"::BULK);

                SetWhseWorksheet(WhseWkshTemplateName, WhseWkshName, LocationCode);
            end;
        }
    }


    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(WorksheetTemplateName; WhseWkshTemplateName)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Template Name';
                        TableRelation = "Whse. Worksheet Template";
                        ToolTip = 'Specifies the name of the template that applies to the movement lines.';
                        Editable = false;

                        trigger OnValidate()
                        begin
                            if WhseWkshTemplateName = '' then
                                WhseWkshName := '';
                        end;
                    }
                    field(WorksheetName; WhseWkshName)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Batch Name';
                        Editable = false;
                    }
                    field(LocCode; LocationCode)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Location Code';
                        TableRelation = Location;
                        Editable = false;
                    }
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }

    var
        WhseWkshTemplateName: Code[10];
        WhseWkshName: Code[10];
        LocationCode: Code[10];
        NextLineNo: Integer;
        G_ReplenishmentWorksheet: Record "Replenishment Worksheet";
        G_TaskletCodeunits: Codeunit Tasklet_Codeunits;

    procedure InitializeRequest(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10]; HideDialog2: Boolean)
    begin
        WhseWkshTemplateName := WhseWkshTemplateName2;
        WhseWkshName := WhseWkshName2;
        LocationCode := LocationCode2;
    end;



    procedure FindEmptyTotesAndCreateRepWorksheet(_ItemNo: Code[20]; _LocationCode: Code[10])
    var
        L_SourceQ: Query WarehouseEntryReceive;
        L_Item: Record Item;
        L_BinContent: Record "Bin Content";
        L_PendingRepl: Record "Replenishment Worksheet";
        L_DupCheck: Record "Replenishment Worksheet";
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        L_ReceiveLocation: Code[20];
        L_ReceiveBULKBin: Code[20];
        L_PickBulkBin: Code[20];
        L_CurrentQtyBase: Decimal;
        L_MinQtyBase: Decimal;
        L_MaxQtyBase: Decimal;
        L_RemQtyToReplenishBase: Decimal;
        L_AvailableSourceQtyBase: Decimal;
        L_QtyToTakeBase: Decimal;
        L_AlreadyAllocatedBase: Decimal;
        L_SourceQtyPerUoM: Decimal;
        L_BinQtyPerUoM: Decimal;
        L_TransferLine: Record "Transfer Line";
        L_TransferRemainingBase: Decimal;
        L_TOAppliedThisBinBase: Decimal;
        L_BinGapBase: Decimal;
    begin
        L_ReceiveLocation := L_KamWhseSetupLookup.GetReceiveLocation();
        L_ReceiveBULKBin := L_KamWhseSetupLookup.GetBulkBin(L_ReceiveLocation);

        // Resolve the BULK bin for THIS item in MAIN. One Item → one BULK bin
        // in PICK BULK, identified by the Bulk flag on Bin (mirrored to Bin
        // Content as a FlowField).
        L_BinContent.Reset();
        L_BinContent.SetRange("Item No.", _ItemNo);
        L_BinContent.SetRange("Location Code", _LocationCode);
        L_BinContent.SetRange(Bulk, true);
        if not L_BinContent.FindFirst() then
            exit;
        L_PickBulkBin := L_BinContent."Bin Code";

        // Total Outstanding qty on existing Transfer Orders (Receive -> destination) for this item.
        // This is a per-item pool consumed across bins (TOs have no destination bin), so each bin
        // applies up to its Max gap and the remainder carries to subsequent bins.
        Clear(L_TransferRemainingBase);
        L_TransferLine.Reset();
        L_TransferLine.SetRange("Item No.", _ItemNo);
        L_TransferLine.SetRange("Transfer-from Code", L_ReceiveLocation);
        L_TransferLine.SetRange("Transfer-to Code", _LocationCode);
        L_TransferLine.SetFilter("Outstanding Qty. (Base)", '>%1', 0);
        if not L_TransferLine.IsEmpty() then begin
            L_TransferLine.CalcSums("Outstanding Qty. (Base)");
            L_TransferRemainingBase := L_TransferLine."Outstanding Qty. (Base)";
        end;

        // Iterate every PICK BULK Bin Content configured for this item (catches brand-new bins with no entries yet)
        L_BinContent.Reset();
        L_BinContent.SetRange("Item No.", _ItemNo);
        L_BinContent.SetRange("Location Code", _LocationCode);
        L_BinContent.SetRange("Bin Code", L_PickBulkBin);
        if L_BinContent.FindSet() then
            repeat
                // Current qty (base) in this destination bin (sums Warehouse Entry via FlowField)
                L_BinContent.CalcFields("Quantity (Base)");
                L_CurrentQtyBase := L_BinContent."Quantity (Base)";
                L_BinQtyPerUoM := L_BinContent."Qty. per Unit of Measure";
                if L_BinQtyPerUoM = 0 then
                    L_BinQtyPerUoM := 1;
                L_MinQtyBase := L_BinContent."Min. Qty." * L_BinQtyPerUoM;
                L_MaxQtyBase := L_BinContent."Max. Qty." * L_BinQtyPerUoM;

                // Apply TO pool to this bin up to its gap-to-Max; remainder carries to next bin.
                Clear(L_TOAppliedThisBinBase);
                L_BinGapBase := L_MaxQtyBase - L_CurrentQtyBase;
                if (L_TransferRemainingBase > 0) and (L_BinGapBase > 0) then begin
                    if L_TransferRemainingBase >= L_BinGapBase then
                        L_TOAppliedThisBinBase := L_BinGapBase
                    else
                        L_TOAppliedThisBinBase := L_TransferRemainingBase;
                    L_TransferRemainingBase := L_TransferRemainingBase - L_TOAppliedThisBinBase;
                end;

                // Trigger replenishment only when below Min Qty AND there is room up to Max Qty (base)
                if ((L_CurrentQtyBase + L_TOAppliedThisBinBase) <= L_MinQtyBase) and
                   (L_MaxQtyBase > (L_CurrentQtyBase + L_TOAppliedThisBinBase))
                then begin
                    L_RemQtyToReplenishBase := L_MaxQtyBase - L_CurrentQtyBase - L_TOAppliedThisBinBase;

                    // Source: BULK location, BULK DECANT or HIGHBAY zones, FEFO (query is ordered by Expiration_Date asc)
                    L_SourceQ.SetFilter(L_SourceQ.Item_No_, '%1', _ItemNo);
                    L_SourceQ.SetFilter(L_SourceQ.Location_Code, '%1', L_ReceiveLocation);
                    L_SourceQ.SetFilter(L_SourceQ.Bin_Code, '%1', L_ReceiveBULKBin);
                    L_SourceQ.SetFilter(L_SourceQ.Expiration_Date, '>=%1', WorkDate());
                    L_SourceQ.SetFilter(L_SourceQ.Qty_Base, '>%1', 0);
                    L_SourceQ.SetFilter(L_SourceQ.Manufacturer_Code, '<>%1', '');
                    L_SourceQ.Open();
                    while (L_RemQtyToReplenishBase > 0) and L_SourceQ.Read() do begin
                        // Skip if a worksheet line already exists for this exact source-lot/destination pair
                        L_DupCheck.Reset();
                        L_DupCheck.SetRange("Template Name", WhseWkshTemplateName);
                        L_DupCheck.SetRange("Batch Name", WhseWkshName);
                        L_DupCheck.SetRange("Item No.", L_SourceQ.Item_No_);
                        L_DupCheck.SetRange("From Location Code", L_SourceQ.Location_Code);
                        L_DupCheck.SetRange("From Bin Code", L_SourceQ.Bin_Code);
                        L_DupCheck.SetRange("Lot No.", L_SourceQ.Lot_No_);
                        L_DupCheck.SetRange("Location Code", L_BinContent."Location Code");
                        L_DupCheck.SetRange("Bin Code", L_BinContent."Bin Code");
                        if L_DupCheck.IsEmpty() then begin
                            // Subtract qty already allocated (base) from this source bin/lot in the worksheet
                            Clear(L_AlreadyAllocatedBase);
                            L_SourceQtyPerUoM := L_SourceQ.Qty_per_Unit_of_Measure;
                            if L_SourceQtyPerUoM = 0 then
                                L_SourceQtyPerUoM := 1;
                            L_PendingRepl.Reset();
                            L_PendingRepl.SetRange("Item No.", L_SourceQ.Item_No_);
                            L_PendingRepl.SetRange("From Location Code", L_SourceQ.Location_Code);
                            L_PendingRepl.SetRange("From Bin Code", L_SourceQ.Bin_Code);
                            L_PendingRepl.SetRange("Lot No.", L_SourceQ.Lot_No_);
                            if not L_PendingRepl.IsEmpty() then begin
                                L_PendingRepl.CalcSums("Qty to Move");
                                L_AlreadyAllocatedBase := L_PendingRepl."Qty to Move" * L_SourceQtyPerUoM;
                            end;

                            L_AvailableSourceQtyBase := L_SourceQ.Qty_Base - L_AlreadyAllocatedBase;
                            if L_AvailableSourceQtyBase > 0 then begin
                                if L_AvailableSourceQtyBase >= L_RemQtyToReplenishBase then
                                    L_QtyToTakeBase := L_RemQtyToReplenishBase
                                else
                                    L_QtyToTakeBase := L_AvailableSourceQtyBase;

                                G_ReplenishmentWorksheet.Init();
                                G_ReplenishmentWorksheet."Posting Date" := WorkDate();
                                G_ReplenishmentWorksheet."Template Name" := WhseWkshTemplateName;
                                G_ReplenishmentWorksheet."Batch Name" := WhseWkshName;
                                G_ReplenishmentWorksheet."Line No." := NextLineNo;
                                G_ReplenishmentWorksheet."Item No." := L_SourceQ.Item_No_;
                                if L_Item.Get(L_SourceQ.Item_No_) then
                                    G_ReplenishmentWorksheet.Description := L_Item.Description;
                                G_ReplenishmentWorksheet."Manufacturer Code" := L_SourceQ.Manufacturer_Code;
                                G_ReplenishmentWorksheet."Manufacturer Name" := CopyStr(G_TaskletCodeunits.GetManufacturerName(G_ReplenishmentWorksheet."Manufacturer Code"), 1, MaxStrLen(G_ReplenishmentWorksheet."Manufacturer Name"));
                                G_ReplenishmentWorksheet."Variant Code" := L_SourceQ.Variant_Code;
                                G_ReplenishmentWorksheet."Unit of Measure Code" := L_SourceQ.Unit_of_Measure_Code;
                                G_ReplenishmentWorksheet."From Location Code" := L_SourceQ.Location_Code;
                                G_ReplenishmentWorksheet."From Bin Code" := L_SourceQ.Bin_Code;
                                G_ReplenishmentWorksheet."Location Code" := L_BinContent."Location Code";
                                G_ReplenishmentWorksheet."Bin Code" := L_BinContent."Bin Code";
                                G_ReplenishmentWorksheet."Lot No." := L_SourceQ.Lot_No_;
                                G_ReplenishmentWorksheet."Package No." := L_SourceQ.Package_No_;
                                G_ReplenishmentWorksheet."Expiration Date" := L_SourceQ.Expiration_Date;
                                G_ReplenishmentWorksheet."Min. Qty." := L_BinContent."Min. Qty.";
                                G_ReplenishmentWorksheet."Max. Qty." := L_BinContent."Max. Qty.";
                                G_ReplenishmentWorksheet."System Quantity" := L_CurrentQtyBase / L_BinQtyPerUoM;
                                G_ReplenishmentWorksheet."Available Qty" := L_AvailableSourceQtyBase / L_SourceQtyPerUoM;
                                G_ReplenishmentWorksheet."Demand Quantity" := (L_MaxQtyBase - L_CurrentQtyBase) / L_BinQtyPerUoM;
                                G_ReplenishmentWorksheet."Qty to Move" := L_QtyToTakeBase / L_SourceQtyPerUoM;
                                G_ReplenishmentWorksheet.Action := G_ReplenishmentWorksheet.Action::Accept;
                                G_ReplenishmentWorksheet.Insert();

                                NextLineNo := NextLineNo + 10000;
                                L_RemQtyToReplenishBase := L_RemQtyToReplenishBase - L_QtyToTakeBase;
                            end;
                        end;
                    end;
                    L_SourceQ.Close();
                end;
            until L_BinContent.Next() = 0;
    end;

    procedure SetWhseWorksheet(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10])
    var
        ReplenishmentWorksheet: Record "Replenishment Worksheet";
    begin
        ReplenishmentWorksheet.SetRange("Template Name", WhseWkshTemplateName2);
        ReplenishmentWorksheet.SetRange("Batch Name", WhseWkshName2);
        ReplenishmentWorksheet.SetRange("Location Code", LocationCode2);
        if ReplenishmentWorksheet.FindLast() then
            NextLineNo := ReplenishmentWorksheet."Line No." + 10000
        else
            NextLineNo := 10000;

        WhseWkshTemplateName := WhseWkshTemplateName2;
        WhseWkshName := WhseWkshName2;
        LocationCode := LocationCode2;
    end;

}

