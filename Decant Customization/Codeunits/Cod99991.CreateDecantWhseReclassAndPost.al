// ============================================================================
//  Cod99991.CreateDecantWhseReclassAndPost.al  —  Phase 2
//
//  Strategy:
//    - FEFO source hydrated ONCE into a temporary "Decant Details";
//      destination bins consume from that in-memory buffer in sequence.
//      No re-opening the query per bin, no per-key dictionary. The temp
//      record is `temporary` so it never reaches the persisted table.
//    - Register writes to "Item Journal Line" (table 83) on an
//      Item Journal Template of type Transfer (Item Reclassification),
//      attaches lot/package tracking via Reservation Entry (table 337),
//      and posts via Codeunit 23 "Item Jnl.-Post Batch". This path works on
//      non-directed locations and does not require Warehouse Employee setup.
//    - The Codeunit.Run call deliberately does NOT use the return value, so
//      BC handles rollback on failure (journal lines + reservation entries
//      are discarded and the Decant Details buffer survives intact).
//    - No Confirm() inside the codeunit (the page already prompts).
//    - All user-facing strings via Label constants at the bottom.
//    - IsHandled OnBefore / OnAfter integration events on every public proc.
// ============================================================================

codeunit 99991 "Decant Reclass Mgt."
{
    Access = Public;

    // -- Public API -----------------------------------------------------------

    procedure CalculateDecant(
        TemplateName: Code[10];
        BatchName: Code[10];
        SourceLocationCode: Code[10];
        DestLocationCode: Code[10];
        ItemFilter: Code[20];
        ManufacturerFilter: Code[50];
        QtyPerToteOverride: Decimal)
    var
        DecantDetails: Record "Decant Details";
        BinContent: Record "Bin Content";
        TempSource: Record "Decant Details" temporary;
        WhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        SourceZone: Code[10];
        DestZone: Code[10];
        NextLineNo: Integer;
        BinsSkippedNoMaxQty: Integer;
        IsHandled: Boolean;
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime();

        IsHandled := false;
        OnBeforeCalculateDecant(SourceLocationCode, DestLocationCode, IsHandled);
        if IsHandled then
            exit;

        ValidateCalculateInputs(SourceLocationCode, DestLocationCode);

        SourceZone := WhseSetupLookup.GetFlowrackZone(SourceLocationCode);
        DestZone := WhseSetupLookup.GetDecantZonefromBinContent(DestLocationCode, ItemFilter);

        if SourceZone = '' then
            Error(GenDecantZoneMissingErr, SourceLocationCode);
        if DestZone = '' then
            Error(GenDecantZoneMissingErr, DestLocationCode);

        ClearBuffer(TemplateName, BatchName);

        // FEFO source — read once into the temp buffer, then consume sequentially.
        LoadSourceBuffer(TempSource, SourceLocationCode, SourceZone, ItemFilter, ManufacturerFilter, QtyPerToteOverride);

        NextLineNo := 10000;

        BinContent.SetRange("Location Code", DestLocationCode);
        BinContent.SetRange("Zone Code", DestZone);
        if ItemFilter <> '' then
            BinContent.SetRange("Item No.", ItemFilter);

        if BinContent.FindSet() then
            repeat
                if BinContent."Max. Qty." <= 0 then
                    BinsSkippedNoMaxQty += 1
                else
                    AllocateToBin(
                        DecantDetails, TempSource, BinContent,
                        TemplateName, BatchName,
                        DestLocationCode, DestZone,
                        ManufacturerFilter, QtyPerToteOverride,
                        NextLineNo);
            until BinContent.Next() = 0;

        if BinsSkippedNoMaxQty > 0 then
            Message(BinsSkippedMsg, BinsSkippedNoMaxQty);

        OnAfterCalculateDecant(TemplateName, BatchName, NextLineNo);
        LogTelemetry('CalculateDecant', SourceLocationCode, DestLocationCode, NextLineNo, StartTime);
    end;

    procedure RegisterDecant(TemplateName: Code[10]; BatchName: Code[10])
    var
        DecantDetails: Record "Decant Details";
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlBatch: Record "Item Journal Batch";
        DocNo: Code[20];
        LineNo: Integer;
        IsHandled: Boolean;
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime();

        IsHandled := false;
        OnBeforeRegisterDecant(TemplateName, BatchName, IsHandled);
        if IsHandled then
            exit;

        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        if not DecantDetails.FindSet() then
            Error(NoLinesToRegisterErr);

        // Fail-early: every Decant Details line must carry a New Package No.
        // before we touch any BC table.
        repeat
            if DecantDetails."New Package No." = '' then
                Error(MissingNewPackageErr, DecantDetails."Line No.");
        until DecantDetails.Next() = 0;

        // Resolve / create the Item Reclassification Journal batch
        // (Item Journal Template of type Transfer).
        EnsureBatch(ItemJnlBatch);

        // Clear leftover lines so retries are idempotent.
        ItemJnlLine.SetRange("Journal Template Name", ItemJnlBatch."Journal Template Name");
        ItemJnlLine.SetRange("Journal Batch Name", ItemJnlBatch.Name);
        ItemJnlLine.DeleteAll(true);

        DocNo := MakeDocNo();
        LineNo := 10000;

        DecantDetails.FindSet();
        repeat
            BuildItemJnlLine(ItemJnlLine, DecantDetails, ItemJnlBatch, DocNo, LineNo);
            AttachItemTracking(ItemJnlLine, DecantDetails);
            LineNo += 10000;
        until DecantDetails.Next() = 0;

        // Post via Codeunit 23. We don't use the return value, so BC handles
        // rollback on failure: the journal-line inserts and reservation
        // entries created above are discarded and Decant Details survives.
        ItemJnlLine.Reset();
        ItemJnlLine.SetRange("Journal Template Name", ItemJnlBatch."Journal Template Name");
        ItemJnlLine.SetRange("Journal Batch Name", ItemJnlBatch.Name);
        if ItemJnlLine.FindFirst() then
            Codeunit.Run(Codeunit::"Item Jnl.-Post Batch", ItemJnlLine);

        // Cleanup only after posting succeeds.
        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.DeleteAll();

        OnAfterRegisterDecant(TemplateName, BatchName);
        LogTelemetry('RegisterDecant', '', '', LineNo, StartTime);
        Message(RegisterCompletedMsg, ItemJnlBatch."Journal Template Name", ItemJnlBatch.Name);
    end;

    // -- Internals ------------------------------------------------------------

    local procedure ValidateCalculateInputs(SourceLocationCode: Code[10]; DestLocationCode: Code[10])
    begin
        if SourceLocationCode = '' then
            Error(SourceLocationMissingErr);
        if DestLocationCode = '' then
            Error(DestLocationMissingErr);
    end;

    local procedure ClearBuffer(TemplateName: Code[10]; BatchName: Code[10])
    var
        DecantDetails: Record "Decant Details";
    begin
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.DeleteAll();
    end;

    local procedure LoadSourceBuffer(
        var TempSource: Record "Decant Details" temporary;
        SourceLocationCode: Code[10];
        SourceZone: Code[10];
        ItemFilter: Code[20];
        ManufacturerFilter: Code[50];
        QtyPerToteOverride: Decimal)
    var
        SourceQuery: Query WarehouseEntryReceive;
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        ItemTrackingSetup: Record "Item Tracking Setup";
        EntriesExist: Boolean;
        LineNo: Integer;
    begin
        // Open the FEFO query exactly once, in expiration-date order (defined
        // on the query itself: OrderBy = ascending(Expiration_Date)).
        SourceQuery.SetFilter(Location_Code, SourceLocationCode);
        SourceQuery.SetFilter(Zone_Code, SourceZone);
        if ItemFilter <> '' then
            SourceQuery.SetFilter(Item_No_, ItemFilter);
        if (ManufacturerFilter <> '') and (QtyPerToteOverride <> 0) then
            SourceQuery.SetFilter(Manufacturer_Code, ManufacturerFilter);
        SourceQuery.SetFilter(Expiration_Date, '>=%1', WorkDate());
        SourceQuery.SetFilter(Qty_Base, '>%1', 0);
        SourceQuery.Open();

        LineNo := 10000;
        while SourceQuery.Read() do begin
            TempSource.Init();
            // Synthetic PK — the temp buffer is in-memory only, these tokens
            // never collide with persisted Decant Details rows.
            TempSource."Journal Template Name" := DecantTempTemplateTok;
            TempSource."Journal Batch Name" := DecantTempBatchTok;
            TempSource."Line No." := LineNo;
            TempSource."Location Code" := SourceQuery.Location_Code;
            TempSource."Item No." := SourceQuery.Item_No_;
            TempSource."Variant Code" := SourceQuery.Variant_Code;
            TempSource."From Zone Code" := SourceQuery.Zone_Code;
            TempSource."From Bin Code" := SourceQuery.Bin_Code;
            TempSource."Lot No." := SourceQuery.Lot_No_;
            TempSource."Package No." := SourceQuery.Package_No_;
            TempSource."Manufacturer Code" := SourceQuery.Manufacturer_Code;
            TempSource."Unit of Measure Code" := SourceQuery.Unit_of_Measure_Code;
            // Transient overloads on the temp record:
            //   "Available Qty. to Take" holds the remaining BASE qty as we
            //     consume across destination bins.
            //   Quantity holds Qty. per Unit of Measure for the UoM conversion.
            TempSource."Available Qty. to Take" := SourceQuery.Qty_Base;
            TempSource.Quantity := SourceQuery.Qty_per_Unit_of_Measure;

            Clear(ItemTrackingSetup);
            ItemTrackingSetup."Lot No." := SourceQuery.Lot_No_;
            TempSource."Expiry Date" :=
                ItemTrackingMgt.ExistingExpirationDate(
                    SourceQuery.Item_No_, '', ItemTrackingSetup, false, EntriesExist);

            TempSource.Insert();
            LineNo += 10000;
        end;
        SourceQuery.Close();
    end;

    local procedure AllocateToBin(
        var DecantDetails: Record "Decant Details";
        var TempSource: Record "Decant Details" temporary;
        BinContent: Record "Bin Content";
        TemplateName: Code[10];
        BatchName: Code[10];
        DestLocationCode: Code[10];
        DestZone: Code[10];
        ManufacturerFilter: Code[50];
        QtyPerToteOverride: Decimal;
        var NextLineNo: Integer)
    var
        RemainingCapacity: Decimal;
        SourceQtyPerUoM: Decimal;
        RemainingFromLot: Decimal;
        QtyPerTote: Decimal;
        ToteQty: Decimal;
        TotesCreatedForBin: Integer;
    begin
        RemainingCapacity := BinContent."Max. Qty.";

        TempSource.Reset();
        TempSource.SetRange("Item No.", BinContent."Item No.");
        TempSource.SetFilter("Available Qty. to Take", '>%1', 0);
        if TempSource.FindSet() then
            repeat
                if RemainingCapacity > 0 then begin
                    // Quantity slot on the temp record carries Qty. per UoM.
                    SourceQtyPerUoM := TempSource.Quantity;
                    if SourceQtyPerUoM = 0 then
                        SourceQtyPerUoM := 1;

                    QtyPerTote := ResolveQtyPerTote(
                        TempSource."Item No.", TempSource."Manufacturer Code",
                        ManufacturerFilter, QtyPerToteOverride);

                    if QtyPerTote > 0 then begin
                        RemainingFromLot := TempSource."Available Qty. to Take";

                        while (RemainingFromLot > 0) and (RemainingCapacity > 0) do begin
                            ToteQty := MinOf3(QtyPerTote, RemainingFromLot, RemainingCapacity);

                            InsertDecantDetail(
                                DecantDetails,
                                TemplateName, BatchName, NextLineNo,
                                TempSource,
                                BinContent, DestLocationCode, DestZone,
                                QtyPerTote, ToteQty, SourceQtyPerUoM);

                            NextLineNo += 10000;
                            TotesCreatedForBin += 1;
                            RemainingFromLot -= ToteQty;
                            RemainingCapacity -= ToteQty;
                        end;

                        // Persist the consumption back onto the temp buffer
                        // so later destination bins see the reduced pool.
                        TempSource."Available Qty. to Take" := RemainingFromLot;
                        TempSource.Modify();
                    end;
                end;
            until TempSource.Next() = 0;

        if TotesCreatedForBin > 0 then
            StampNumberOfTotes(TemplateName, BatchName, BinContent, DestLocationCode, TotesCreatedForBin);
    end;

    local procedure ResolveQtyPerTote(
        ItemNo: Code[20];
        SourceManufacturerCode: Code[50];
        FilterManufacturer: Code[50];
        OverrideQty: Decimal): Decimal
    var
        ItemManufacturer: Record "Item Manufacturer Table";
    begin
        if (FilterManufacturer <> '') and (OverrideQty <> 0) then
            exit(OverrideQty);

        if ItemManufacturer.Get(ItemNo, SourceManufacturerCode) then
            exit(ItemManufacturer."Qty per Tote");

        exit(0);
    end;

    local procedure InsertDecantDetail(
        var DecantDetails: Record "Decant Details";
        TemplateName: Code[10];
        BatchName: Code[10];
        LineNo: Integer;
        TempSource: Record "Decant Details" temporary;
        BinContent: Record "Bin Content";
        DestLocationCode: Code[10];
        DestZone: Code[10];
        QtyPerTote: Decimal;
        ToteQty: Decimal;
        SourceQtyPerUoM: Decimal)
    var
        Item: Record Item;
    begin
        DecantDetails.Init();
        DecantDetails."Journal Template Name" := TemplateName;
        DecantDetails."Journal Batch Name" := BatchName;
        DecantDetails."Line No." := LineNo;
        DecantDetails."Item No." := TempSource."Item No.";
        DecantDetails."Variant Code" := TempSource."Variant Code";
        DecantDetails."Location Code" := TempSource."Location Code";
        DecantDetails."From Zone Code" := TempSource."From Zone Code";
        DecantDetails."From Bin Code" := TempSource."From Bin Code";
        DecantDetails."Lot No." := TempSource."Lot No.";
        DecantDetails.Quantity := ToteQty / SourceQtyPerUoM;
        DecantDetails."Unit of Measure Code" := TempSource."Unit of Measure Code";
        DecantDetails."To Location Code" := DestLocationCode;
        DecantDetails."To Zone Code" := DestZone;
        DecantDetails."To Bin Code" := BinContent."Bin Code";
        DecantDetails."Manufacturer Code" := TempSource."Manufacturer Code";
        DecantDetails."Qty Per Tote" := QtyPerTote;
        DecantDetails."To Qty." := ToteQty / SourceQtyPerUoM;
        DecantDetails."New Package No." := '';
        DecantDetails."Expiry Date" := TempSource."Expiry Date";
        DecantDetails."Package No." := TempSource."Package No.";
        if Item.Get(TempSource."Item No.") then
            DecantDetails.Description := Item.Description;
        DecantDetails.Insert();
    end;

    local procedure StampNumberOfTotes(
        TemplateName: Code[10];
        BatchName: Code[10];
        BinContent: Record "Bin Content";
        DestLocationCode: Code[10];
        TotesCreated: Integer)
    var
        DecantDetails: Record "Decant Details";
    begin
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.SetRange("Item No.", BinContent."Item No.");
        DecantDetails.SetRange("To Location Code", DestLocationCode);
        DecantDetails.SetRange("To Bin Code", BinContent."Bin Code");
        DecantDetails.ModifyAll("Number of Totes", TotesCreated);
    end;

    local procedure EnsureBatch(var ItemJnlBatch: Record "Item Journal Batch")
    var
        ItemJnlTemplate: Record "Item Journal Template";
    begin
        ItemJnlTemplate.SetRange(Type, ItemJnlTemplate.Type::Transfer);
        if not ItemJnlTemplate.FindFirst() then
            Error(ItemTemplateMissingErr);

        if ItemJnlBatch.Get(ItemJnlTemplate.Name, DefaultBatchNameTok) then
            exit;

        ItemJnlBatch.Init();
        ItemJnlBatch."Journal Template Name" := ItemJnlTemplate.Name;
        ItemJnlBatch.Name := DefaultBatchNameTok;
        ItemJnlBatch.Description := DefaultBatchDescTok;
        ItemJnlBatch.Insert(true);
    end;

    local procedure BuildItemJnlLine(
        var ItemJnlLine: Record "Item Journal Line";
        DecantDetails: Record "Decant Details";
        ItemJnlBatch: Record "Item Journal Batch";
        DocNo: Code[20];
        LineNo: Integer)
    begin
        ItemJnlLine.Init();
        ItemJnlLine."Journal Template Name" := ItemJnlBatch."Journal Template Name";
        ItemJnlLine."Journal Batch Name" := ItemJnlBatch.Name;
        ItemJnlLine."Line No." := LineNo;

        ItemJnlLine.Validate("Posting Date", WorkDate());
        ItemJnlLine."Document No." := DocNo;
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Transfer;

        ItemJnlLine.Validate("Item No.", DecantDetails."Item No.");
        if DecantDetails."Variant Code" <> '' then
            ItemJnlLine.Validate("Variant Code", DecantDetails."Variant Code");
        ItemJnlLine.Validate("Location Code", DecantDetails."Location Code");
        ItemJnlLine.Validate("New Location Code", DecantDetails."To Location Code");

        // Bin Codes are direct — Validate would re-resolve via the new
        // location and may reject cross-location values during build.
        ItemJnlLine."Bin Code" := DecantDetails."From Bin Code";
        ItemJnlLine."New Bin Code" := DecantDetails."To Bin Code";

        ItemJnlLine."Manufacturer Code" := DecantDetails."Manufacturer Code";
        ItemJnlLine.Validate(Quantity, DecantDetails."To Qty.");
        if DecantDetails."Unit of Measure Code" <> '' then
            ItemJnlLine.Validate("Unit of Measure Code", DecantDetails."Unit of Measure Code");

        ItemJnlLine.Insert(true);
    end;

    local procedure AttachItemTracking(
        ItemJnlLine: Record "Item Journal Line";
        DecantDetails: Record "Decant Details")
    var
        TempReservEntry: Record "Reservation Entry";
        ReservEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservStatus: Enum "Reservation Status";
    begin
        TempReservEntry.Init();
        TempReservEntry."Lot No." := DecantDetails."Lot No.";
        if DecantDetails."Expiry Date" <> 0D then
            TempReservEntry."Expiration Date" := DecantDetails."Expiry Date";

        CreateReservEntry.CreateReservEntryFor(
            Database::"Item Journal Line",
            ItemJnlLine."Entry Type".AsInteger(),
            ItemJnlLine."Journal Template Name",
            ItemJnlLine."Journal Batch Name",
            0,
            ItemJnlLine."Line No.",
            ItemJnlLine."Qty. per Unit of Measure",
            ItemJnlLine.Quantity,
            ItemJnlLine.Quantity,
            TempReservEntry);
        CreateReservEntry.SetDates(0D, DecantDetails."Expiry Date");
        CreateReservEntry.CreateEntry(
            ItemJnlLine."Item No.",
            ItemJnlLine."Variant Code",
            ItemJnlLine."Location Code",
            '',
            0D,
            0D,
            0,
            ReservStatus::Surplus);

        // Back-fill the New tracking fields on the entry we just created.
        ReservEntry.SetRange("Source Type", Database::"Item Journal Line");
        ReservEntry.SetRange("Source Subtype", ItemJnlLine."Entry Type".AsInteger());
        ReservEntry.SetRange("Source ID", ItemJnlLine."Journal Template Name");
        ReservEntry.SetRange("Source Batch Name", ItemJnlLine."Journal Batch Name");
        ReservEntry.SetRange("Source Ref. No.", ItemJnlLine."Line No.");
        ReservEntry.SetRange("Lot No.", DecantDetails."Lot No.");
        if ReservEntry.FindLast() then begin
            ReservEntry."New Lot No." := DecantDetails."Lot No.";
            ReservEntry."Package No." := DecantDetails."Package No.";
            ReservEntry."New Package No." := DecantDetails."New Package No.";
            ReservEntry."Manufacturer Code" := DecantDetails."Manufacturer Code";
            if DecantDetails."Expiry Date" <> 0D then
                ReservEntry."New Expiration Date" := DecantDetails."Expiry Date";
            ReservEntry.Modify();
        end;
    end;

    local procedure MakeDocNo(): Code[20]
    begin
        exit('GENDEC-' + Format(WorkDate(), 0, '<Year4><Month,2><Day,2>'));
    end;

    local procedure MinOf3(A: Decimal; B: Decimal; C: Decimal): Decimal
    var
        Result: Decimal;
    begin
        Result := A;
        if B < Result then
            Result := B;
        if C < Result then
            Result := C;
        exit(Result);
    end;

    local procedure LogTelemetry(EventName: Text; LocationCode: Text; DestLocationCode: Text; LineCount: Integer; StartTime: DateTime)
    var
        TelemetryDimensions: Dictionary of [Text, Text];
    begin
        TelemetryDimensions.Add('Event', EventName);
        TelemetryDimensions.Add('SourceLocation', LocationCode);
        TelemetryDimensions.Add('DestLocation', DestLocationCode);
        TelemetryDimensions.Add('Lines', Format(LineCount));
        TelemetryDimensions.Add('DurationMs', Format(CurrentDateTime() - StartTime));
        Session.LogMessage(
            'KAM-DECANT-0001',
            StrSubstNo(TelemetryMsgTok, EventName),
            Verbosity::Normal,
            DataClassification::SystemMetadata,
            TelemetryScope::ExtensionPublisher,
            TelemetryDimensions);
    end;

    // -- Integration events ---------------------------------------------------

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalculateDecant(
        var SourceLocationCode: Code[10];
        var DestLocationCode: Code[10];
        var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCalculateDecant(
        TemplateName: Code[10];
        BatchName: Code[10];
        LinesCreated: Integer)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRegisterDecant(
        var TemplateName: Code[10];
        var BatchName: Code[10];
        var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterRegisterDecant(
        TemplateName: Code[10];
        BatchName: Code[10])
    begin
    end;

    // -- Labels ---------------------------------------------------------------

    var
        SourceLocationMissingErr: Label 'Source Location Code must be specified.';
        DestLocationMissingErr: Label 'Destination Location Code must be specified.';
        GenDecantZoneMissingErr: Label 'GEN DECANT zone not found for Location %1.', Comment = '%1 = Location Code';
        ItemTemplateMissingErr: Label 'No Item Journal Template of type Transfer (Reclassification) was found. Configure one before running Register.';
        NoLinesToRegisterErr: Label 'There are no Decant Detail lines to register for the selected batch.';
        MissingNewPackageErr: Label 'New Package No. is required on Decant Detail line %1 before registration.', Comment = '%1 = Line No.';
        BinsSkippedMsg: Label '%1 destination bin(s) were skipped because Max. Qty. is zero. Configure bin capacity to include them.', Comment = '%1 = number of bins';
        RegisterCompletedMsg: Label 'Decant reclassification registered successfully.\Template: %1\nBatch: %2', Comment = '%1 = template, %2 = batch';
        DefaultBatchNameTok: Label 'GENDECANT', Locked = true;
        DefaultBatchDescTok: Label 'GEN DECANT Reclassification', Locked = true;
        DecantTempTemplateTok: Label 'DECANT-TMP', Locked = true;
        DecantTempBatchTok: Label 'TMP', Locked = true;
        TelemetryMsgTok: Label 'Decant %1 completed.', Locked = true, Comment = '%1 = event name';
}
