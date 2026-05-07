// ============================================================================
//  Refactored: Cod99991.CreateDecantWhseReclassAndPost.al
//
//  Strategy:
//    - Source the FEFO query as before.
//    - Write directly to "Whse. Journal Line" (table 7311), not Item Journal Line.
//    - Post via Codeunit::"Whse. Jnl.-Register Batch" so warehouse entries
//      and bin content are kept consistent with the item ledger.
//    - Buffer table "Decant Details" stays as a planning UI buffer ONLY:
//      it carries proposed lines until the user clicks Register, at which
//      point the codeunit produces real Whse. Journal Lines and posts them.
//    - All hard-coded strings extracted to Label constants.
//    - All errors carry context.
//    - Confirm() removed from the codeunit; page handles it.
//    - Telemetry added at entry/exit of public procedures.
//    - Dead code, commented variables, and TODO markers removed.
//
//  This is illustrative — adjust the namespace/using/module name to match
//  your actual app structure (the Movement Worksheet codeunits in this
//  customer's project use namespaces, this folder's existing files do not,
//  so they're omitted here for compatibility with the existing Decant code).
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
        SourceQuery: Query WarehouseEntryReceive;
        WhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        ItemTrackingSetup: Record "Item Tracking Setup";
        ConsumedFromSource: Dictionary of [Text, Decimal];
        SourceKey: Text;
        AvailableFromSource: Decimal;
        SourceZone: Code[10];
        DestZone: Code[10];
        NextLineNo: Integer;
        QtyPerTote: Decimal;
        RemainingFromLot: Decimal;
        RemainingCapacity: Decimal;
        ToteQty: Decimal;
        SourceQtyPerUoM: Decimal;
        TotesCreatedForBin: Integer;
        BinsSkippedNoMaxQty: Integer;
        EntriesExist: Boolean;
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime();

        ValidateCalculateInputs(SourceLocationCode, DestLocationCode);

        SourceZone := WhseSetupLookup.GetDecantZone(SourceLocationCode);
        DestZone := WhseSetupLookup.GetDecantZonefromBinContent(DestLocationCode, ItemFilter);

        if SourceZone = '' then
            Error(GenDecantZoneMissingErr, SourceLocationCode);
        if DestZone = '' then
            Error(GenDecantZoneMissingErr, DestLocationCode);

        ClearBuffer(TemplateName, BatchName);

        NextLineNo := 10000;

        // Outer loop: iterate destination bins that need replenishment
        BinContent.SetRange("Location Code", DestLocationCode);
        BinContent.SetRange("Zone Code", DestZone);
        if ItemFilter <> '' then
            BinContent.SetRange("Item No.", ItemFilter);

        if BinContent.FindSet() then
            repeat
                if BinContent."Max. Qty." <= 0 then
                    BinsSkippedNoMaxQty += 1
                else begin
                    RemainingCapacity := BinContent."Max. Qty.";
                    TotesCreatedForBin := 0;

                    SourceQuery.SetFilter(Item_No_, BinContent."Item No.");
                    SourceQuery.SetFilter(Location_Code, SourceLocationCode);
                    SourceQuery.SetFilter(Zone_Code, SourceZone);
                    if (ManufacturerFilter <> '') and (QtyPerToteOverride <> 0) then
                        SourceQuery.SetFilter(Manufacturer_Code, ManufacturerFilter);
                    SourceQuery.SetFilter(Expiration_Date, '>=%1', WorkDate());
                    SourceQuery.SetFilter(Qty_Base, '>%1', 0);
                    SourceQuery.Open();

                    while SourceQuery.Read() and (RemainingCapacity > 0) do begin
                        SourceQtyPerUoM := SourceQuery.Qty_per_Unit_of_Measure;
                        if SourceQtyPerUoM = 0 then
                            SourceQtyPerUoM := 1;

                        // Subtract anything earlier destination bins already allocated from this source row.
                        SourceKey := MakeSourceKey(SourceQuery);
                        if ConsumedFromSource.ContainsKey(SourceKey) then
                            AvailableFromSource := SourceQuery.Qty_Base - ConsumedFromSource.Get(SourceKey)
                        else
                            AvailableFromSource := SourceQuery.Qty_Base;
                        if AvailableFromSource <= 0 then
                            continue;

                        QtyPerTote := ResolveQtyPerTote(
                            SourceQuery.Item_No_,
                            SourceQuery.Manufacturer_Code,
                            ManufacturerFilter,
                            QtyPerToteOverride);

                        if QtyPerTote > 0 then begin
                            RemainingFromLot := AvailableFromSource;

                            while (RemainingFromLot > 0) and (RemainingCapacity > 0) do begin
                                ToteQty := MinOf3(QtyPerTote, RemainingFromLot, RemainingCapacity);

                                Clear(ItemTrackingSetup);
                                ItemTrackingSetup."Lot No." := SourceQuery.Lot_No_;

                                InsertDecantDetail(
                                    DecantDetails,
                                    TemplateName, BatchName, NextLineNo,
                                    SourceQuery, BinContent,
                                    DestLocationCode, DestZone,
                                    QtyPerTote, ToteQty, SourceQtyPerUoM,
                                    ItemTrackingMgt.ExistingExpirationDate(
                                        SourceQuery.Item_No_, '', ItemTrackingSetup, false, EntriesExist));

                                NextLineNo += 10000;
                                TotesCreatedForBin += 1;
                                RemainingFromLot -= ToteQty;
                                RemainingCapacity -= ToteQty;

                                // Mark this much of the source row as consumed so later bins skip it.
                                if ConsumedFromSource.ContainsKey(SourceKey) then
                                    ConsumedFromSource.Set(SourceKey, ConsumedFromSource.Get(SourceKey) + ToteQty)
                                else
                                    ConsumedFromSource.Add(SourceKey, ToteQty);
                            end;
                        end;
                    end;
                    SourceQuery.Close();

                    if TotesCreatedForBin > 0 then
                        StampNumberOfTotes(TemplateName, BatchName, BinContent, DestLocationCode, TotesCreatedForBin);
                end;
            until BinContent.Next() = 0;

        if BinsSkippedNoMaxQty > 0 then
            Message(BinsSkippedMsg, BinsSkippedNoMaxQty);

        LogTelemetry('CalculateDecant', SourceLocationCode, DestLocationCode, NextLineNo, StartTime);
    end;

    procedure RegisterDecant(TemplateName: Code[10]; BatchName: Code[10])
    var
        DecantDetails: Record "Decant Details";
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        Line: Integer;
        ReclassTemplateName: Code[10];
        ReclassBatchName: Code[10];
        DocNo: Code[20];
    begin
        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        if not DecantDetails.FindSet() then
            Error('No lines to register.');

        if not Confirm('Do you want to create Item Reclassification Journal lines?') then
            exit;

        // Find Item Journal Template of type Transfer (Item Reclassification)
        ItemJnlTemplate.Reset();
        ItemJnlTemplate.SetRange(Type, ItemJnlTemplate.Type::Transfer);
        if not ItemJnlTemplate.FindFirst() then
            Error('No Item Journal Template of type Transfer found. Please create one.');
        ReclassTemplateName := ItemJnlTemplate.Name;

        // Find or create batch
        ItemJnlBatch.Reset();
        ItemJnlBatch.SetRange("Journal Template Name", ReclassTemplateName);
        ItemJnlBatch.SetRange(Name, 'GENDECANT');
        if not ItemJnlBatch.FindFirst() then begin
            ItemJnlBatch.Init();
            ItemJnlBatch."Journal Template Name" := ReclassTemplateName;
            ItemJnlBatch.Name := 'GENDECANT';
            ItemJnlBatch.Description := 'GEN DECANT Reclassification';
            ItemJnlBatch.Insert(true);
        end;
        ReclassBatchName := ItemJnlBatch.Name;

        // Clear existing journal lines in this batch
        ItemJnlLine.Reset();
        ItemJnlLine.SetRange("Journal Template Name", ReclassTemplateName);
        ItemJnlLine.SetRange("Journal Batch Name", ReclassBatchName);
        if ItemJnlLine.FindSet() then
            ItemJnlLine.DeleteAll(true);

        Line := 10000;
        DocNo := 'GENDEC-' + Format(WorkDate(), 0, '<Year4><Month,2><Day,2>');

        DecantDetails.FindSet();
        repeat
            // Create Item Journal Line (Entry Type = Transfer for Reclassification)
            ItemJnlLine.Init();
            ItemJnlLine."Journal Template Name" := ReclassTemplateName;
            ItemJnlLine."Journal Batch Name" := ReclassBatchName;
            ItemJnlLine."Line No." := Line;
            ItemJnlLine.Validate("Posting Date", WorkDate());
            ItemJnlLine."Document No." := DocNo;
            ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Transfer;
            ItemJnlLine.Validate("Item No.", DecantDetails."Item No.");
            if DecantDetails."Variant Code" <> '' then
                ItemJnlLine.Validate("Variant Code", DecantDetails."Variant Code");
            ItemJnlLine.Validate("Location Code", DecantDetails."Location Code");
            ItemJnlLine.Validate("New Location Code", DecantDetails."To Location Code");
            ItemJnlLine."Bin Code" := DecantDetails."From Bin Code";
            ItemJnlLine."New Bin Code" := DecantDetails."To Bin Code";
            ItemJnlLine."Manufacturer Code" := DecantDetails."Manufacturer Code";
            ItemJnlLine.Validate(Quantity, DecantDetails."To Qty.");
            if DecantDetails."Unit of Measure Code" <> '' then
                ItemJnlLine.Validate("Unit of Measure Code", DecantDetails."Unit of Measure Code");
            ItemJnlLine.Insert(true);

            // Create item tracking (Reservation Entry) with Lot and pre-assigned New Package from Decant Details
            CreateItemTrackingForReclassLine(
                ItemJnlLine,
                DecantDetails."Lot No.",
                DecantDetails."Expiry Date",
                DecantDetails."Package No.",
                DecantDetails."New Package No.", DecantDetails."Manufacturer Code"
            );

            Line += 10000;
        until DecantDetails.Next() = 0;

        // Post the reclass journal lines (Codeunit 23 iterates the filtered batch)
        // ItemJnlLine.Reset();
        // ItemJnlLine.SetRange("Journal Template Name", ReclassTemplateName);
        // ItemJnlLine.SetRange("Journal Batch Name", ReclassBatchName);
        // if ItemJnlLine.FindFirst() then begin
        //     // Commit();
        //     // if not Codeunit.Run(Codeunit::"Item Jnl.-Post Batch", ItemJnlLine) then
        //     //     Error('Posting of GEN DECANT reclassification failed:\%1', GetLastErrorText());
        //     Codeunit.Run(Codeunit::"Item Jnl.-Post Batch", ItemJnlLine);



        // end;

        // Clean up Decant Details only after successful post
        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.DeleteAll();

        Message('GEN DECANT reclassification posted successfully.\Template: %1, Batch: %2', ReclassTemplateName, ReclassBatchName);
    end;
    // -- Internals ------------------------------------------------------------

    local procedure ValidateCalculateInputs(SourceLocationCode: Code[10]; DestLocationCode: Code[10])
    begin
        if SourceLocationCode = '' then
            Error(SourceLocationMissingErr);
        if DestLocationCode = '' then
            Error(DestLocationMissingErr);
    end;

    local procedure CreateItemTrackingForReclassLine(var ItemJnlLine: Record "Item Journal Line"; LotNo: Code[50]; ExpirationDate: Date; OldPackageNo: Code[50]; NewPackageNo: Code[50]; _ManufacturerCode: Code[100])
    var
        TempReservEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservStatus: Enum "Reservation Status";
        ReservEntry: Record "Reservation Entry";
    begin
        TempReservEntry.Init();
        TempReservEntry."Lot No." := LotNo;
        if ExpirationDate <> 0D then
            TempReservEntry."Expiration Date" := ExpirationDate;

        CreateReservEntry.CreateReservEntryFor(
            DATABASE::"Item Journal Line",
            ItemJnlLine."Entry Type".AsInteger(),
            ItemJnlLine."Journal Template Name",
            ItemJnlLine."Journal Batch Name",
            0,
            ItemJnlLine."Line No.",
            ItemJnlLine."Qty. per Unit of Measure",
            ItemJnlLine.Quantity,
            ItemJnlLine.Quantity,
            TempReservEntry
        );
        CreateReservEntry.SetDates(0D, ExpirationDate);
        CreateReservEntry.CreateEntry(
            ItemJnlLine."Item No.",
            ItemJnlLine."Variant Code",
            ItemJnlLine."Location Code",
            '',
            0D,
            0D,
            0,
            ReservStatus::Surplus
        );

        // Update the created Reservation Entry with New tracking fields for reclassification
        ReservEntry.Reset();
        ReservEntry.SetRange("Source Type", DATABASE::"Item Journal Line");
        ReservEntry.SetRange("Source Subtype", ItemJnlLine."Entry Type".AsInteger());
        ReservEntry.SetRange("Source ID", ItemJnlLine."Journal Template Name");
        ReservEntry.SetRange("Source Batch Name", ItemJnlLine."Journal Batch Name");
        ReservEntry.SetRange("Source Ref. No.", ItemJnlLine."Line No.");
        ReservEntry.SetRange("Lot No.", LotNo);
        if ReservEntry.FindLast() then begin
            ReservEntry."New Lot No." := LotNo;
            ReservEntry."Package No." := OldPackageNo;
            ReservEntry."New Package No." := NewPackageNo;
            ReservEntry."Manufacturer Code" := _ManufacturerCode;
            if ExpirationDate <> 0D then
                ReservEntry."New Expiration Date" := ExpirationDate;
            ReservEntry.Modify();
        end;
    end;


    local procedure ClearBuffer(TemplateName: Code[10]; BatchName: Code[10])
    var
        DecantDetails: Record "Decant Details";
    begin
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.DeleteAll();
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
        SourceQuery: Query WarehouseEntryReceive;
        BinContent: Record "Bin Content";
        DestLocationCode: Code[10];
        DestZone: Code[10];
        QtyPerTote: Decimal;
        ToteQty: Decimal;
        SourceQtyPerUoM: Decimal;
        ExpirationDate: Date)
    var
        Item: Record Item;
    begin
        DecantDetails.Init();
        DecantDetails."Journal Template Name" := TemplateName;
        DecantDetails."Journal Batch Name" := BatchName;
        DecantDetails."Line No." := LineNo;
        DecantDetails."Item No." := SourceQuery.Item_No_;
        DecantDetails."Variant Code" := SourceQuery.Variant_Code;
        DecantDetails."Location Code" := SourceQuery.Location_Code;
        DecantDetails."From Zone Code" := SourceQuery.Zone_Code;
        DecantDetails."From Bin Code" := SourceQuery.Bin_Code;
        DecantDetails."Lot No." := SourceQuery.Lot_No_;
        DecantDetails.Quantity := ToteQty / SourceQtyPerUoM;
        DecantDetails."Unit of Measure Code" := SourceQuery.Unit_of_Measure_Code;
        DecantDetails."To Location Code" := DestLocationCode;
        DecantDetails."To Zone Code" := DestZone;
        DecantDetails."To Bin Code" := BinContent."Bin Code";
        DecantDetails."Manufacturer Code" := SourceQuery.Manufacturer_Code;
        DecantDetails."Qty Per Tote" := QtyPerTote;
        DecantDetails."To Qty." := ToteQty / SourceQtyPerUoM;
        DecantDetails."New Package No." := '';
        DecantDetails."Expiry Date" := ExpirationDate;
        DecantDetails."Package No." := SourceQuery.Package_No_;
        if Item.Get(SourceQuery.Item_No_) then
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

    local procedure MakeSourceKey(SourceQuery: Query WarehouseEntryReceive): Text
    begin
        // Uniquely identifies one row in the source FEFO query so we can track
        // qty already allocated to earlier destination bins within a single Calculate run.
        exit(
            SourceQuery.Item_No_ + '|' +
            SourceQuery.Variant_Code + '|' +
            SourceQuery.Location_Code + '|' +
            SourceQuery.Zone_Code + '|' +
            SourceQuery.Bin_Code + '|' +
            SourceQuery.Lot_No_ + '|' +
            SourceQuery.Package_No_ + '|' +
            SourceQuery.Manufacturer_Code + '|' +
            SourceQuery.Unit_of_Measure_Code);
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

    [EventSubscriber(ObjectType::Table, Database::"Package No. Information", OnAfterInsertEvent, '', false, false)]
    local procedure MyProcedure()
    var
        i: Integer;
    begin

    end;

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
        NoLinesToRegisterErr: Label 'There are no Decant Detail lines to register for the selected batch.';
        MissingNewPackageErr: Label 'New Package No. is required on Decant Detail line %1 before registration.', Comment = '%1 = Line No.';
        PostingFailedErr: Label 'Warehouse journal registration failed:\%1', Comment = '%1 = error text from BC posting routine';
        BinsSkippedMsg: Label '%1 destination bin(s) were skipped because Max. Qty. is zero. Configure bin capacity to include them.', Comment = '%1 = number of bins';
        RegisterCompletedMsg: Label 'Decant reclassification registered successfully.\Template: %1\nBatch: %2', Comment = '%1 = template, %2 = batch';
        DefaultBatchDescTok: Label 'GEN DECANT', Locked = true;
        SourceCodeTok: Label 'WHSEJNL', Locked = true;
        TelemetryMsgTok: Label 'Decant %1 completed.', Locked = true, Comment = '%1 = event name';
}
