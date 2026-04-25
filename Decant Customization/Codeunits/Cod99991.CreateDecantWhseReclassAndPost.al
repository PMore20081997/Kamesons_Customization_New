codeunit 99991 CreateDecantWhseReclassAndPost
{
    procedure CreateWarehouseReclassJournals(var LotNoInformation: Record "Lot No. Information")
    begin

    end;

    procedure CalculateGenDecant(TemplateName: Code[10]; BatchName: Code[10]; SourceLocationCode: Code[10]; DestLocationCode: Code[10]; ItemFilter: Code[50]; _ManufacturerFilter: Code[100]; _QtyPerToteOverride: Decimal)
    var
        SourceQuery: Query WarehouseEntryReceive;
        DecantDetails: Record "Decant Details";
        Events: Codeunit Events;
        SourceZone: Code[10];
        DestZone: Code[10];
        BinContent: Record "Bin Content";
        RecItem: Record Item;
        ItemManufacturer: Record "Item Manufacturer Table";
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        ItemTrackingSetup: Record "Item Tracking Setup";
        EntriesExist: Boolean;
        Line: Integer;
        QtyPerTote: Decimal;
        RemainingFromLot: Decimal;
        RemainingCapacity: Decimal;
        ToteQty: Decimal;
        MaxBinQty: Decimal;
        TotesCreated: Integer;
        SourceQtyPerUoM: Decimal;
    begin
        if SourceLocationCode = '' then
            Error('Source Location Code must be specified.');
        if DestLocationCode = '' then
            Error('Destination Location Code must be specified.');

        SourceZone := Events.GetGenDecantZone(SourceLocationCode);
        //DestZone := Events.GetGenDecantZone(DestLocationCode);
        DestZone := Events.GetGenDecantZonefromBinContent(DestLocationCode, ItemFilter); //Temporary need to change for multiple Items.

        if SourceZone = '' then
            Error('GEN DECANT Zone not found for Location %1.', SourceLocationCode);
        if DestZone = '' then
            Error('GEN DECANT Zone not found for Location %1.', DestLocationCode);

        // Clear existing lines for this batch
        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        if DecantDetails.FindSet() then
            DecantDetails.DeleteAll();
        Commit();

        Line := 10000;

        // Outer loop: Iterate Bin Content at destination GEN DECANT to find items needing replenishment
        BinContent.Reset();
        BinContent.SetRange("Location Code", DestLocationCode);
        BinContent.SetRange("Zone Code", DestZone);
        if ItemFilter <> '' then
            BinContent.SetRange("Item No.", ItemFilter);

        if BinContent.FindSet() then
            repeat
                MaxBinQty := BinContent."Max. Qty.";
                if MaxBinQty > 0 then begin
                    // Trigger replenishment when destination GEN DECANT stock falls below the PICK BULK bin's Min. Qty.
                    //if GetDestinationStock(BinContent."Item No.", DestLocationCode, DestZone) < GetMAINWHMinQty(BinContent."Item No.", DestLocationCode) then begin
                    RemainingCapacity := MaxBinQty;
                    TotesCreated := 0;

                    // Inner loop: Query source lots for this item, FEFO ordered (earliest expiry first)
                    SourceQuery.SetFilter(SourceQuery.Item_No_, BinContent."Item No.");
                    SourceQuery.SetFilter(SourceQuery.Location_Code, SourceLocationCode);
                    SourceQuery.SetFilter(SourceQuery.Zone_Code, SourceZone);
                    if (_ManufacturerFilter <> '') AND (_QtyPerToteOverride <> 0) then
                        SourceQuery.SetFilter(SourceQuery.Manufacturer_Code, _ManufacturerFilter);
                    SourceQuery.SetFilter(Expiration_Date, '>=%1', WorkDate());
                    SourceQuery.SetFilter(Qty_Base, '>%1', 0);
                    SourceQuery.Open();

                    while SourceQuery.Read() and (RemainingCapacity > 0) do begin
                        if SourceQuery.Qty_Base > 0 then begin
                            SourceQtyPerUoM := SourceQuery.Qty_per_Unit_of_Measure;
                            if SourceQtyPerUoM = 0 then
                                SourceQtyPerUoM := 1;
                            // Look up Qty per Tote from Item Manufacturer Table using source Manufacturer Code
                            //if ItemManufacturer.Get(SourceQuery.Item_No_, SourceQuery.Manufacturer_Code) then begin

                            ItemManufacturer.Reset();
                            ItemManufacturer.SetRange("Item No", SourceQuery.Item_No_);
                            if (_ManufacturerFilter <> '') AND (_QtyPerToteOverride <> 0) then
                                ItemManufacturer.SetRange("Manufacturer code", _ManufacturerFilter)
                            else
                                ItemManufacturer.SetRange("Manufacturer code", SourceQuery.Manufacturer_Code);
                            if ItemManufacturer.FindFirst() then begin
                                if _QtyPerToteOverride <> 0 then
                                    QtyPerTote := _QtyPerToteOverride
                                else
                                    QtyPerTote := ItemManufacturer."Qty per Tote";

                                if QtyPerTote > 0 then begin
                                    RemainingFromLot := SourceQuery.Qty_Base;

                                    // Split this lot into tote-sized lines until lot or destination capacity is exhausted
                                    while (RemainingFromLot > 0) and (RemainingCapacity > 0) do begin
                                        // Tote qty = full tote, or whatever is left in the lot, or whatever capacity remains (partial tote)
                                        ToteQty := QtyPerTote;
                                        if RemainingFromLot < ToteQty then
                                            ToteQty := RemainingFromLot;
                                        if RemainingCapacity < ToteQty then
                                            ToteQty := RemainingCapacity;

                                        DecantDetails.Init();
                                        DecantDetails."Journal Template Name" := TemplateName;
                                        DecantDetails."Journal Batch Name" := BatchName;
                                        DecantDetails."Line No." := Line;
                                        DecantDetails."Item No." := SourceQuery.Item_No_;
                                        DecantDetails."Variant Code" := SourceQuery.Variant_Code;
                                        DecantDetails."Location Code" := SourceQuery.Location_Code;
                                        DecantDetails."From Zone Code" := SourceQuery.Zone_Code;
                                        DecantDetails."From Bin Code" := SourceQuery.Bin_Code;
                                        DecantDetails."Lot No." := SourceQuery.Lot_No_;
                                        DecantDetails.Quantity := ToteQty / SourceQtyPerUoM;
                                        DecantDetails."Unit of Measure Code" := SourceQuery.Unit_of_Measure_Code;

                                        // Destination
                                        DecantDetails."To Location Code" := DestLocationCode;
                                        DecantDetails."To Zone Code" := DestZone;
                                        DecantDetails."To Bin Code" := BinContent."Bin Code";

                                        // Tote info - Manufacturer from source Warehouse Entry
                                        DecantDetails."Manufacturer Code" := SourceQuery.Manufacturer_Code;
                                        DecantDetails."Qty Per Tote" := QtyPerTote;
                                        DecantDetails."To Qty." := ToteQty / SourceQtyPerUoM;

                                        // User will decide "New Package No." on the page; keep blank here
                                        DecantDetails."New Package No." := '';

                                        // Get expiry date from lot tracking
                                        Clear(ItemTrackingSetup);
                                        ItemTrackingSetup."Lot No." := SourceQuery.Lot_No_;
                                        DecantDetails."Expiry Date" := ItemTrackingMgt.ExistingExpirationDate(
                                            SourceQuery.Item_No_, '',
                                            ItemTrackingSetup, false, EntriesExist);
                                        DecantDetails."Package No." := SourceQuery.Package_No_;

                                        // Get item description
                                        if RecItem.Get(SourceQuery.Item_No_) then
                                            DecantDetails.Description := RecItem.Description;

                                        DecantDetails.Insert();
                                        Line += 10000;
                                        TotesCreated += 1;
                                        RemainingFromLot -= ToteQty;
                                        RemainingCapacity -= ToteQty;
                                    end;
                                end;
                            end;
                        end;
                    end;
                    SourceQuery.Close();

                    // Write the total tote count onto every line created for this destination bin
                    if TotesCreated > 0 then begin
                        DecantDetails.Reset();
                        DecantDetails.SetRange("Journal Template Name", TemplateName);
                        DecantDetails.SetRange("Journal Batch Name", BatchName);
                        DecantDetails.SetRange("Item No.", BinContent."Item No.");
                        DecantDetails.SetRange("To Location Code", DestLocationCode);
                        DecantDetails.SetRange("To Bin Code", BinContent."Bin Code");
                        DecantDetails.ModifyAll("Number of Totes", TotesCreated);
                    end;
                end;
            until BinContent.Next() = 0;
    end;

    local procedure GetMAINWHMinQty(ItemNo: Code[20]; LocationCode: Code[10]): Decimal
    var
        GENDECBin: Record "Bin Content";
        Events: Codeunit Events;
        GENDECNTZone: Code[10];
        TotalMinQty: Decimal;
    begin
        GENDECNTZone := Events.GetGenDecantZone(LocationCode);
        if GENDECNTZone = '' then
            exit(0);

        GENDECBin.Reset();
        GENDECBin.SetRange("Location Code", LocationCode);
        GENDECBin.SetRange("Zone Code", GENDECNTZone);
        GENDECBin.SetRange("Item No.", ItemNo);
        if GENDECBin.FindSet() then
            repeat
                TotalMinQty += GENDECBin."Min. Qty.";
            until GENDECBin.Next() = 0;
        exit(TotalMinQty);
    end;

    local procedure GetDestinationStock(ItemNo: Code[20]; LocationCode: Code[10]; ZoneCode: Code[10]): Decimal
    var
        DestQuery: Query WhseDetailsMainGenDcnt;
        TotalQty: Decimal;
    begin
        TotalQty := 0;
        DestQuery.SetFilter(DestQuery.Item_No_, ItemNo);
        DestQuery.SetFilter(DestQuery.Location_Code, LocationCode);
        DestQuery.SetFilter(DestQuery.Zone_Code, ZoneCode);
        DestQuery.Open();
        while DestQuery.Read() do
            TotalQty += DestQuery.Qty_Base;
        DestQuery.Close();
        exit(TotalQty);
    end;

    procedure RegisterGenDecant(TemplateName: Code[10]; BatchName: Code[10])
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
        ItemJnlLine.Reset();
        ItemJnlLine.SetRange("Journal Template Name", ReclassTemplateName);
        ItemJnlLine.SetRange("Journal Batch Name", ReclassBatchName);
        if ItemJnlLine.FindFirst() then begin
            // Commit();
            // if not Codeunit.Run(Codeunit::"Item Jnl.-Post Batch", ItemJnlLine) then
            //     Error('Posting of GEN DECANT reclassification failed:\%1', GetLastErrorText());
            Codeunit.Run(Codeunit::"Item Jnl.-Post Batch", ItemJnlLine);



        end;

        // Clean up Decant Details only after successful post
        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.DeleteAll();

        Message('GEN DECANT reclassification posted successfully.\Template: %1, Batch: %2', ReclassTemplateName, ReclassBatchName);
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

    var
        G_ItemTrackingSetup: Record "Item Tracking Setup";
        G_SalesAndRecSetup: Record "Sales & Receivables Setup";
        G_WhseJournalBatch: Record "Warehouse Journal Batch";
        G_WhseJournalLine: Record "Warehouse Journal Line";
}
