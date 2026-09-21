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
        G_DecantDetails: Record "Decant Details";
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
        L_PendingRepl: Record "Decant Details";
        L_DupCheck: Record "Decant Details";
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
                        L_DupCheck.SetRange("Journal Template Name", WhseWkshTemplateName);
                        L_DupCheck.SetRange("Journal Batch Name", WhseWkshName);
                        L_DupCheck.SetRange("Entry Type", L_DupCheck."Entry Type"::Replenishment);
                        L_DupCheck.SetRange("Item No.", L_SourceQ.Item_No_);
                        // "Location Code" on Decant Details = source (Receive) location
                        L_DupCheck.SetRange("Location Code", CopyStr(L_SourceQ.Location_Code, 1, MaxStrLen(L_DupCheck."Location Code")));
                        L_DupCheck.SetRange("From Bin Code", L_SourceQ.Bin_Code);
                        L_DupCheck.SetRange("Lot No.", L_SourceQ.Lot_No_);
                        L_DupCheck.SetRange("To Location Code", CopyStr(L_BinContent."Location Code", 1, MaxStrLen(L_DupCheck."To Location Code")));
                        L_DupCheck.SetRange("To Bin Code", L_BinContent."Bin Code");
                        if L_DupCheck.IsEmpty() then begin
                            // Subtract qty already allocated (base) from this source bin/lot in the worksheet
                            Clear(L_AlreadyAllocatedBase);
                            L_SourceQtyPerUoM := L_SourceQ.Qty_per_Unit_of_Measure;
                            if L_SourceQtyPerUoM = 0 then
                                L_SourceQtyPerUoM := 1;
                            L_PendingRepl.Reset();
                            L_PendingRepl.SetRange("Entry Type", L_PendingRepl."Entry Type"::Replenishment);
                            L_PendingRepl.SetRange("Item No.", L_SourceQ.Item_No_);
                            L_PendingRepl.SetRange("Location Code", CopyStr(L_SourceQ.Location_Code, 1, MaxStrLen(L_PendingRepl."Location Code")));
                            L_PendingRepl.SetRange("From Bin Code", L_SourceQ.Bin_Code);
                            L_PendingRepl.SetRange("Lot No.", L_SourceQ.Lot_No_);
                            if not L_PendingRepl.IsEmpty() then begin
                                L_PendingRepl.CalcSums("To Qty.");
                                L_AlreadyAllocatedBase := L_PendingRepl."To Qty." * L_SourceQtyPerUoM;
                            end;

                            L_AvailableSourceQtyBase := L_SourceQ.Qty_Base - L_AlreadyAllocatedBase;
                            if L_AvailableSourceQtyBase > 0 then begin
                                if L_AvailableSourceQtyBase >= L_RemQtyToReplenishBase then
                                    L_QtyToTakeBase := L_RemQtyToReplenishBase
                                else
                                    L_QtyToTakeBase := L_AvailableSourceQtyBase;

                                G_DecantDetails.Init();
                                G_DecantDetails."Journal Template Name" := WhseWkshTemplateName;
                                G_DecantDetails."Journal Batch Name" := WhseWkshName;
                                G_DecantDetails."Line No." := NextLineNo;
                                G_DecantDetails."Entry Type" := G_DecantDetails."Entry Type"::Replenishment;
                                G_DecantDetails."Status" := G_DecantDetails."Status"::Accept;
                                G_DecantDetails."Posting Date" := WorkDate();
                                G_DecantDetails."Item No." := L_SourceQ.Item_No_;
                                if L_Item.Get(L_SourceQ.Item_No_) then
                                    G_DecantDetails.Description := L_Item.Description;
                                G_DecantDetails."Manufacturer Code" := L_SourceQ.Manufacturer_Code;
                                G_DecantDetails."Manufacturer Name" := CopyStr(G_TaskletCodeunits.GetManufacturerName(G_DecantDetails."Manufacturer Code"), 1, MaxStrLen(G_DecantDetails."Manufacturer Name"));
                                G_DecantDetails."Variant Code" := L_SourceQ.Variant_Code;
                                G_DecantDetails."Unit of Measure Code" := L_SourceQ.Unit_of_Measure_Code;
                                // "Location Code" on Decant Details = source (Receive) location
                                G_DecantDetails."Location Code" := CopyStr(L_SourceQ.Location_Code, 1, MaxStrLen(G_DecantDetails."Location Code"));
                                G_DecantDetails."From Bin Code" := L_SourceQ.Bin_Code;
                                // "To Location Code" on Decant Details = destination (MAIN warehouse)
                                G_DecantDetails."To Location Code" := CopyStr(L_BinContent."Location Code", 1, MaxStrLen(G_DecantDetails."To Location Code"));
                                G_DecantDetails."To Bin Code" := L_BinContent."Bin Code";
                                G_DecantDetails."Lot No." := L_SourceQ.Lot_No_;
                                G_DecantDetails."Package No." := CopyStr(L_SourceQ.Package_No_, 1, MaxStrLen(G_DecantDetails."Package No."));
                                G_DecantDetails."Expiry Date" := L_SourceQ.Expiration_Date;
                                G_DecantDetails."Available Qty. to Take" := L_AvailableSourceQtyBase / L_SourceQtyPerUoM;
                                G_DecantDetails."To Qty." := L_QtyToTakeBase / L_SourceQtyPerUoM;
                                G_DecantDetails.Insert();

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
        L_DecantDetails: Record "Decant Details";
    begin
        // Line numbering continues within the template/batch. "Location Code" is NOT
        // filtered here: on Decant Details it holds the SOURCE location, not LocationCode2
        // (the destination), so filtering on it would restart numbering and risk collisions.
        L_DecantDetails.SetRange("Journal Template Name", WhseWkshTemplateName2);
        L_DecantDetails.SetRange("Journal Batch Name", WhseWkshName2);
        L_DecantDetails.SetRange("Entry Type", L_DecantDetails."Entry Type"::Replenishment);
        if L_DecantDetails.FindLast() then
            NextLineNo := L_DecantDetails."Line No." + 10000
        else
            NextLineNo := 10000;

        WhseWkshTemplateName := WhseWkshTemplateName2;
        WhseWkshName := WhseWkshName2;
        LocationCode := LocationCode2;
    end;

}

