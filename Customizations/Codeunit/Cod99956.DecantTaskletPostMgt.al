namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Tracking;

/// <summary>
/// Tasklet-side decant posting. Mirrors the body of
/// Cod99991.CreateDecantWhseReclassAndPost.RegisterDecant but:
///   - runs head-less (no Confirm),
///   - actually posts the Item Reclass journal (Codeunit::"Item Jnl.-Post Batch"),
///   - is intentionally separate so changes to the Tasklet posting flow never
///     destabilise the BC Register button.
///
/// When the BC Register button is retired, Cod99991.RegisterDecant can be
/// deleted without touching this codeunit.
/// </summary>
codeunit 99956 "Decant Tasklet Post Mgt."
{
    Access = Public;

    var
        NoLinesToPostErr: Label 'No Decant Details lines found for Template %1 / Batch %2.', Comment = '%1 = Template, %2 = Batch';
        LineNotFoundErr: Label 'Decant Details line %1 not found in Template %2 / Batch %3.', Comment = '%1 = Line No., %2 = Template, %3 = Batch';
        NoTransferTemplateErr: Label 'No Item Journal Template of type Transfer is configured. Configure an Item Reclassification template before posting from Tasklet.';
        PostingFailedErr: Label 'Posting the Item Reclassification journal failed:\%1', Comment = '%1 = error text from the post codeunit';
        ReclassBatchNameTok: Label 'GENDECANT', Locked = true;
        ReclassBatchDescLbl: Label 'GEN DECANT Reclassification';
        DocNoPrefixTok: Label 'GENDEC-', Locked = true;

    /// <summary>
    /// Writes scanned values back onto a single Decant Details row without posting.
    /// Used by the per-line "Save" path on the Tasklet device. The user can later
    /// post the row individually (PostSingleDecantLine) or post the whole batch
    /// (PostDecantBatchFromTasklet).
    /// </summary>
    procedure SaveScanForDecantLine(TemplateName: Code[10]; BatchName: Code[10]; LineNo: Integer; NewToBinCode: Code[20]; NewPackageNo: Code[50])
    var
        DecantDetails: Record "Decant Details";
    begin
        if not FindDecantLine(TemplateName, BatchName, LineNo, DecantDetails) then
            Error(LineNotFoundErr, LineNo, TemplateName, BatchName);

        // Direct assignment for "To Bin Code" — the table's TableRelation looks at
        // FIELD("Location Code") (the source location) when the bin actually lives
        // in the destination location, so Validate() would fail. New Package No.
        // keeps Validate so its duplicate-check OnValidate still fires.
        if NewToBinCode <> '' then
            DecantDetails."To Bin Code" := NewToBinCode;
        if NewPackageNo <> '' then
            DecantDetails.Validate("New Package No.", NewPackageNo);
        DecantDetails.Modify(true);
    end;

    /// <summary>
    /// Posts ONE Decant Details row: optionally applies scanned values, then
    /// creates an Item Reclass Journal line for that row, posts it, and deletes
    /// the row. Used by the per-line "Post" path on the Tasklet device.
    /// </summary>
    procedure PostSingleDecantLine(TemplateName: Code[10]; BatchName: Code[10]; LineNo: Integer; NewToBinCode: Code[20]; NewPackageNo: Code[50])
    var
        DecantDetails: Record "Decant Details";
        ItemJnlLine: Record "Item Journal Line";
        ReclassTemplateName: Code[10];
        ReclassBatchName: Code[10];
        DocNo: Code[20];
    begin
        if not FindDecantLine(TemplateName, BatchName, LineNo, DecantDetails) then
            Error(LineNotFoundErr, LineNo, TemplateName, BatchName);

        // See note in SaveScanForDecantLine — bypass Validate on "To Bin Code"
        // because its TableRelation filters by the source location, not destination.
        if NewToBinCode <> '' then
            DecantDetails."To Bin Code" := NewToBinCode;
        if NewPackageNo <> '' then
            DecantDetails.Validate("New Package No.", NewPackageNo);
        DecantDetails.Modify(true);

        ResolveReclassTemplateAndBatch(ReclassTemplateName, ReclassBatchName);

        // Clear any leftover lines for this batch so single-line posting doesn't
        // sweep previously-staged unrelated rows along with it.
        ItemJnlLine.Reset();
        ItemJnlLine.SetRange("Journal Template Name", ReclassTemplateName);
        ItemJnlLine.SetRange("Journal Batch Name", ReclassBatchName);
        if ItemJnlLine.FindSet() then
            ItemJnlLine.DeleteAll(true);

        DocNo := DocNoPrefixTok + Format(WorkDate(), 0, '<Year4><Month,2><Day,2>');
        CreateReclassJournalLine(DecantDetails, ReclassTemplateName, ReclassBatchName, DocNo, 10000);

        PostReclassBatch(ReclassTemplateName, ReclassBatchName);

        DecantDetails.Delete();
    end;

    /// <summary>
    /// Public entry point invoked by the Tasklet Decant Screen codeunit after
    /// scanned values (To Bin, New Package No.) have been written back onto
    /// the Decant Details rows. Creates Item Reclass Journal lines for every
    /// row in the batch, posts them, and clears the buffer on success.
    /// </summary>
    procedure PostDecantBatchFromTasklet(TemplateName: Code[10]; BatchName: Code[10])
    var
        DecantDetails: Record "Decant Details";
        ItemJnlLine: Record "Item Journal Line";
        ReclassTemplateName: Code[10];
        ReclassBatchName: Code[10];
        DocNo: Code[20];
        Line: Integer;
    begin
        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        if not DecantDetails.FindSet() then
            Error(NoLinesToPostErr, TemplateName, BatchName);

        ResolveReclassTemplateAndBatch(ReclassTemplateName, ReclassBatchName);

        ItemJnlLine.Reset();
        ItemJnlLine.SetRange("Journal Template Name", ReclassTemplateName);
        ItemJnlLine.SetRange("Journal Batch Name", ReclassBatchName);
        if ItemJnlLine.FindSet() then
            ItemJnlLine.DeleteAll(true);

        Line := 10000;
        DocNo := DocNoPrefixTok + Format(WorkDate(), 0, '<Year4><Month,2><Day,2>');

        repeat
            CreateReclassJournalLine(DecantDetails, ReclassTemplateName, ReclassBatchName, DocNo, Line);
            Line += 10000;
        until DecantDetails.Next() = 0;

        PostReclassBatch(ReclassTemplateName, ReclassBatchName);

        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.DeleteAll();
    end;

    local procedure FindDecantLine(TemplateName: Code[10]; BatchName: Code[10]; LineNo: Integer; var DecantDetails: Record "Decant Details"): Boolean
    begin
        DecantDetails.Reset();
        DecantDetails.SetRange("Journal Template Name", TemplateName);
        DecantDetails.SetRange("Journal Batch Name", BatchName);
        DecantDetails.SetRange("Line No.", LineNo);
        exit(DecantDetails.FindFirst());
    end;

    local procedure ResolveReclassTemplateAndBatch(var ReclassTemplateName: Code[10]; var ReclassBatchName: Code[10])
    var
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
    begin
        ItemJnlTemplate.Reset();
        ItemJnlTemplate.SetRange(Type, ItemJnlTemplate.Type::Transfer);
        if not ItemJnlTemplate.FindFirst() then
            Error(NoTransferTemplateErr);
        ReclassTemplateName := ItemJnlTemplate.Name;

        ItemJnlBatch.Reset();
        ItemJnlBatch.SetRange("Journal Template Name", ReclassTemplateName);
        ItemJnlBatch.SetRange(Name, ReclassBatchNameTok);
        if not ItemJnlBatch.FindFirst() then begin
            ItemJnlBatch.Init();
            ItemJnlBatch."Journal Template Name" := ReclassTemplateName;
            ItemJnlBatch.Name := ReclassBatchNameTok;
            ItemJnlBatch.Description := ReclassBatchDescLbl;
            ItemJnlBatch.Insert(true);
        end;
        ReclassBatchName := ItemJnlBatch.Name;
    end;

    local procedure CreateReclassJournalLine(var DecantDetails: Record "Decant Details"; ReclassTemplateName: Code[10]; ReclassBatchName: Code[10]; DocNo: Code[20]; LineNo: Integer)
    var
        ItemJnlLine: Record "Item Journal Line";
    begin
        ItemJnlLine.Init();
        ItemJnlLine."Journal Template Name" := ReclassTemplateName;
        ItemJnlLine."Journal Batch Name" := ReclassBatchName;
        ItemJnlLine."Line No." := LineNo;
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

        CreateItemTrackingForLine(
            ItemJnlLine,
            DecantDetails."Lot No.",
            DecantDetails."Expiry Date",
            DecantDetails."Package No.",
            DecantDetails."New Package No.",
            DecantDetails."Manufacturer Code");
    end;

    local procedure CreateItemTrackingForLine(var ItemJnlLine: Record "Item Journal Line"; LotNo: Code[50]; ExpirationDate: Date; OldPackageNo: Code[50]; NewPackageNo: Code[50]; ManufacturerCode: Code[10])
    var
        TempReservEntry: Record "Reservation Entry";
        ReservEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservStatus: Enum "Reservation Status";
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
            TempReservEntry);
        CreateReservEntry.SetDates(0D, ExpirationDate);
        CreateReservEntry.CreateEntry(
            ItemJnlLine."Item No.",
            ItemJnlLine."Variant Code",
            ItemJnlLine."Location Code",
            '',
            0D,
            0D,
            0,
            ReservStatus::Surplus);

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
            ReservEntry."Manufacturer Code" := ManufacturerCode;
            if ExpirationDate <> 0D then
                ReservEntry."New Expiration Date" := ExpirationDate;
            ReservEntry.Modify();
        end;
    end;

    local procedure PostReclassBatch(ReclassTemplateName: Code[10]; ReclassBatchName: Code[10])
    var
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
    begin
        ItemJnlLine.Reset();
        ItemJnlLine.SetRange("Journal Template Name", ReclassTemplateName);
        ItemJnlLine.SetRange("Journal Batch Name", ReclassBatchName);
        if not ItemJnlLine.FindFirst() then
            exit;

        Commit();
        if not ItemJnlPostBatch.Run(ItemJnlLine) then
            Error(PostingFailedErr, GetLastErrorText());
    end;
}
