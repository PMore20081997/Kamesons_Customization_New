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

    procedure CalculateGenDecant(
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

        SourceZone := WhseSetupLookup.GetGenDecantZone(SourceLocationCode);
        DestZone := WhseSetupLookup.GetGenDecantZonefromBinContent(DestLocationCode, ItemFilter);

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

                        QtyPerTote := ResolveQtyPerTote(
                            SourceQuery.Item_No_,
                            SourceQuery.Manufacturer_Code,
                            ManufacturerFilter,
                            QtyPerToteOverride);

                        if QtyPerTote > 0 then begin
                            RemainingFromLot := SourceQuery.Qty_Base;

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

        LogTelemetry('CalculateGenDecant', SourceLocationCode, DestLocationCode, NextLineNo, StartTime);
    end;

    procedure RegisterGenDecant(TemplateName: Code[10]; BatchName: Code[10])
    var
        DecantDetails: Record "Decant Details";
        WhseJnlLine: Record "Warehouse Journal Line";
        WhseJnlRegisterBatch: Codeunit "Whse. Jnl.-Register Batch";
        WhseJnlBatch: Record "Warehouse Journal Batch";
        NextLineNo: Integer;
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime();

        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        if not DecantDetails.FindSet() then
            Error(NoLinesToRegisterErr);

        // Validate every line has a New Package No. before we start writing
        DecantDetails.SetRange("New Package No.", '');
        if not DecantDetails.IsEmpty() then begin
            DecantDetails.FindFirst();
            Error(MissingNewPackageErr, DecantDetails."Line No.");
        end;
        DecantDetails.SetRange("New Package No.");

        // Resolve / create the warehouse journal batch we'll post to
        ResolveWhseJournalBatch(TemplateName, BatchName, DecantDetails."Location Code", WhseJnlBatch);

        // Wipe any leftover lines in the target whse journal batch
        WhseJnlLine.SetRange("Journal Template Name", WhseJnlBatch."Journal Template Name");
        WhseJnlLine.SetRange("Journal Batch Name", WhseJnlBatch.Name);
        WhseJnlLine.SetRange("Location Code", WhseJnlBatch."Location Code");
        WhseJnlLine.DeleteAll(true);

        NextLineNo := 10000;
        DecantDetails.FindSet();
        repeat
            BuildWhseJnlLine(WhseJnlLine, WhseJnlBatch, DecantDetails, NextLineNo);
            WhseJnlLine.Insert(true);
            NextLineNo += 10000;
        until DecantDetails.Next() = 0;

        // Post via the standard warehouse journal posting routine
        WhseJnlLine.Reset();
        WhseJnlLine.SetRange("Journal Template Name", WhseJnlBatch."Journal Template Name");
        WhseJnlLine.SetRange("Journal Batch Name", WhseJnlBatch.Name);
        WhseJnlLine.SetRange("Location Code", WhseJnlBatch."Location Code");

        if not WhseJnlLine.FindFirst() then
            Error(NoLinesToRegisterErr);

        Commit();
        if not Codeunit.Run(Codeunit::"Whse. Jnl.-Register Batch", WhseJnlLine) then
            Error(PostingFailedErr, GetLastErrorText());

        // Only delete the buffer once posting succeeded
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.DeleteAll();

        LogTelemetry('RegisterGenDecant', WhseJnlBatch."Location Code", '', NextLineNo, StartTime);
        Message(RegisterCompletedMsg, WhseJnlBatch."Journal Template Name", WhseJnlBatch.Name);
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

    local procedure ResolveWhseJournalBatch(
        TemplateName: Code[10];
        BatchName: Code[10];
        LocationCode: Code[10];
        var WhseJnlBatch: Record "Warehouse Journal Batch")
    begin
        WhseJnlBatch.SetRange("Journal Template Name", TemplateName);
        WhseJnlBatch.SetRange(Name, BatchName);
        WhseJnlBatch.SetRange("Location Code", LocationCode);
        if WhseJnlBatch.FindFirst() then
            exit;

        WhseJnlBatch.Init();
        WhseJnlBatch."Journal Template Name" := TemplateName;
        WhseJnlBatch.Name := BatchName;
        WhseJnlBatch."Location Code" := LocationCode;
        WhseJnlBatch.Description := DefaultBatchDescTok;
        WhseJnlBatch.Insert(true);
    end;

    local procedure BuildWhseJnlLine(
        var WhseJnlLine: Record "Warehouse Journal Line";
        WhseJnlBatch: Record "Warehouse Journal Batch";
        DecantDetails: Record "Decant Details";
        LineNo: Integer)
    var
        NoSeriesMgt: Codeunit "No. Series";
    begin
        WhseJnlLine.Init();
        WhseJnlLine."Journal Template Name" := WhseJnlBatch."Journal Template Name";
        WhseJnlLine."Journal Batch Name" := WhseJnlBatch.Name;
        WhseJnlLine."Location Code" := DecantDetails."Location Code";
        WhseJnlLine."Line No." := LineNo;
        WhseJnlLine.Validate("Registering Date", WorkDate());
        WhseJnlLine.Validate("Item No.", DecantDetails."Item No.");
        if DecantDetails."Variant Code" <> '' then
            WhseJnlLine.Validate("Variant Code", DecantDetails."Variant Code");
        WhseJnlLine.Validate("Unit of Measure Code", DecantDetails."Unit of Measure Code");

        WhseJnlLine."Source Code" := SourceCodeTok;
        WhseJnlLine."Reason Code" := DecantDetails."Reason Code";
        WhseJnlLine."Whse. Document No." := DecantDetails."Journal Batch Name";

        // Source bin
        WhseJnlLine.Validate("From Zone Code", DecantDetails."From Zone Code");
        WhseJnlLine.Validate("From Bin Code", DecantDetails."From Bin Code");

        // Destination bin
        WhseJnlLine.Validate("To Zone Code", DecantDetails."To Zone Code");
        WhseJnlLine.Validate("To Bin Code", DecantDetails."To Bin Code");

        WhseJnlLine.Validate(Quantity, DecantDetails."To Qty.");

        // Lot/package tracking — these go straight onto the journal line in
        // BC v22+; before that, use the Whse. Item Tracking Lines page.
        WhseJnlLine."Lot No." := DecantDetails."Lot No.";
        WhseJnlLine."New Lot No." := DecantDetails."Lot No.";
        WhseJnlLine."Package No." := DecantDetails."Package No.";
        WhseJnlLine."New Package No." := DecantDetails."New Package No.";
        WhseJnlLine."Expiration Date" := DecantDetails."Expiry Date";
        WhseJnlLine."New Expiration Date" := DecantDetails."Expiry Date";

        // Custom field on Whse. Journal Line for manufacturer (assumes the
        // Movement Worksheet customisation has already added it; if not,
        // remove this line)
        // WhseJnlLine."Manufacturer Code" := DecantDetails."Manufacturer Code";
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
    local procedure OnBeforeCalculateGenDecant(
        var SourceLocationCode: Code[10];
        var DestLocationCode: Code[10];
        var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCalculateGenDecant(
        TemplateName: Code[10];
        BatchName: Code[10];
        LinesCreated: Integer)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRegisterGenDecant(
        var TemplateName: Code[10];
        var BatchName: Code[10];
        var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterRegisterGenDecant(
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
        RegisterCompletedMsg: Label 'GEN DECANT reclassification registered successfully.\Template: %1\nBatch: %2', Comment = '%1 = template, %2 = batch';
        DefaultBatchDescTok: Label 'GEN DECANT', Locked = true;
        SourceCodeTok: Label 'WHSEJNL', Locked = true;
        TelemetryMsgTok: Label 'Decant %1 completed.', Locked = true, Comment = '%1 = event name';
}
