// Global namespace (no `namespace` declaration), matching the Decant reclass
// codeunit (Cod99991): object references resolve by name. The "Registered Whse.
// Activity" objects do not live in Microsoft.Warehouse.Activity, so a namespaced
// file would need an explicit `using` for their (version-specific) namespace.

/// <summary>
/// US xxxxx — Pallet-No. reclassification engine for registered Put-Aways.
///
/// PURPOSE
///   After a Put-Away is registered, the operator-entered "Pallet No." (carried
///   onto each registered Place line) must become the stored stock's Package No.
///   This codeunit posts an in-place Item Reclassification (Transfer) per Place
///   line: same Item / Lot / Expiry / Bin / Qty, with New Package No. = Pallet No.
///   It mirrors the proven posting path in "Decant Reclass Mgt." (Cod99991) /
///   "Decant Tasklet Post Mgt." (Cod99956): an Item Journal of type Transfer +
///   Reservation Entry + Codeunit 23 "Item Jnl.-Post Batch".
///
/// TWO ENTRY POINTS
///   * Auto — codeunit "Pallet Reclass Subscribers NDPP" calls this via
///     Codeunit.Run on OnAfterRegisterWhseActivity (OnRun below). Running it
///     trapped means a posting failure rolls back to the savepoint: the
///     registration is preserved and the lines stay un-posted for manual retry.
///   * Manual — the "Registered Put-away" page action calls
///     ProcessRegisteredPutAway(Rec, true) directly so errors surface to the user.
///
/// GUARD (mirrors standard "don't re-create an already-registered put-away")
///   Only lines with "Pallet Reclass Posted" = FALSE are processed, and the flag
///   is set as part of the same transaction as the post. A manual re-run on a
///   fully-posted document therefore finds nothing and errors out.
/// </summary>
codeunit 99966 "Pallet Reclass Mgt. NDPP"
{
    TableNo = "Registered Whse. Activity Hdr.";
    Permissions = tabledata "Registered Whse. Activity Line" = rm,
                  tabledata "Item Journal Line" = rimd,
                  tabledata "Item Journal Batch" = rim,
                  tabledata "Reservation Entry" = rimd;

    // Auto path — invoked trapped via Codeunit.Run so a posting failure never
    // aborts the registration. Never throws the "already posted" guard here.
    trigger OnRun()
    begin
        ProcessRegisteredPutAway(Rec, false);
    end;

    /// <summary>
    /// Reclassifies Package No. -> Pallet No. for every not-yet-posted Place line
    /// on the registered Put-Away document. ManualInvocation = TRUE surfaces the
    /// guard ("nothing to reclassify") and a success message; FALSE stays silent
    /// (auto path).
    /// </summary>
    procedure ProcessRegisteredPutAway(var RegHeader: Record "Registered Whse. Activity Hdr."; ManualInvocation: Boolean)
    var
        RegLine: Record "Registered Whse. Activity Line";
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlBatch: Record "Item Journal Batch";
        DocNo: Code[20];
        LineNo: Integer;
    begin
        // Only Put-Away documents carry pallet reclassification.
        if RegHeader.Type <> RegHeader.Type::"Put-away" then begin
            if ManualInvocation then
                Error(NotPutAwayErr);
            exit;
        end;

        if not FindReclassLines(RegHeader, RegLine) then begin
            if ManualInvocation then
                Error(AlreadyReclassifiedErr);
            exit;
        end;

        EnsureBatch(ItemJnlBatch);

        // Clear any leftover lines so retries are idempotent.
        ItemJnlLine.SetRange("Journal Template Name", ItemJnlBatch."Journal Template Name");
        ItemJnlLine.SetRange("Journal Batch Name", ItemJnlBatch.Name);
        ItemJnlLine.DeleteAll(true);

        DocNo := RegHeader."No.";
        LineNo := 10000;

        RegLine.FindSet();
        repeat
            BuildItemJnlLine(ItemJnlLine, RegLine, ItemJnlBatch, DocNo, LineNo);
            AttachItemTracking(ItemJnlLine, RegLine);
            LineNo += 10000;
        until RegLine.Next() = 0;

        // Set the guard flag BEFORE posting so the whole operation is atomic:
        // if the post errors, the transaction rolls back and the flag reverts;
        // if it commits, the flag persists alongside the relabelled stock.
        RegLine.ModifyAll("Pallet Reclass Posted", true);

        // Post via Codeunit 23. The return value is deliberately ignored so BC
        // handles rollback on failure (journal lines + reservation entries are
        // discarded; on the auto path the outer Codeunit.Run traps the error).
        ItemJnlLine.Reset();
        ItemJnlLine.SetRange("Journal Template Name", ItemJnlBatch."Journal Template Name");
        ItemJnlLine.SetRange("Journal Batch Name", ItemJnlBatch.Name);
        if ItemJnlLine.FindFirst() then
            Codeunit.Run(Codeunit::"Item Jnl.-Post Batch", ItemJnlLine);

        if ManualInvocation then
            Message(ReclassPostedMsg, RegHeader."No.");
    end;

    /// <summary>
    /// Filters RegLine to the un-posted Place lines of the document that carry a
    /// Pallet No. Returns FALSE (with no records) when there is nothing to do.
    /// </summary>
    local procedure FindReclassLines(var RegHeader: Record "Registered Whse. Activity Hdr."; var RegLine: Record "Registered Whse. Activity Line"): Boolean
    begin
        RegLine.SetRange("Activity Type", RegLine."Activity Type"::"Put-away");
        RegLine.SetRange("No.", RegHeader."No.");
        RegLine.SetRange("Action Type", RegLine."Action Type"::Place);
        RegLine.SetFilter("Pallet No.", '<>%1', '');
        RegLine.SetRange("Pallet Reclass Posted", false);
        exit(not RegLine.IsEmpty());
    end;

    local procedure EnsureBatch(var ItemJnlBatch: Record "Item Journal Batch")
    var
        ItemJnlTemplate: Record "Item Journal Template";
    begin
        ItemJnlTemplate.SetRange(Type, ItemJnlTemplate.Type::Transfer);
        if not ItemJnlTemplate.FindFirst() then
            Error(NoTransferTemplateErr);

        if ItemJnlBatch.Get(ItemJnlTemplate.Name, BatchNameTok) then
            exit;

        ItemJnlBatch.Init();
        ItemJnlBatch."Journal Template Name" := ItemJnlTemplate.Name;
        ItemJnlBatch.Name := BatchNameTok;
        ItemJnlBatch.Description := BatchDescLbl;
        ItemJnlBatch.Insert(true);
    end;

    local procedure BuildItemJnlLine(var ItemJnlLine: Record "Item Journal Line"; RegLine: Record "Registered Whse. Activity Line"; ItemJnlBatch: Record "Item Journal Batch"; DocNo: Code[20]; LineNo: Integer)
    begin
        ItemJnlLine.Init();
        ItemJnlLine."Journal Template Name" := ItemJnlBatch."Journal Template Name";
        ItemJnlLine."Journal Batch Name" := ItemJnlBatch.Name;
        ItemJnlLine."Line No." := LineNo;

        ItemJnlLine.Validate("Posting Date", WorkDate());
        ItemJnlLine."Document No." := DocNo;
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Transfer;

        ItemJnlLine.Validate("Item No.", RegLine."Item No.");
        if RegLine."Variant Code" <> '' then
            ItemJnlLine.Validate("Variant Code", RegLine."Variant Code");
        ItemJnlLine.Validate("Location Code", RegLine."Location Code");
        ItemJnlLine.Validate("New Location Code", RegLine."Location Code");

        // Same bin in and out — this is an in-place package relabel, not a move.
        // Set directly: Validate would re-resolve via the new location.
        ItemJnlLine."Bin Code" := RegLine."Bin Code";
        ItemJnlLine."New Bin Code" := RegLine."Bin Code";

        if RegLine."Unit of Measure Code" <> '' then
            ItemJnlLine.Validate("Unit of Measure Code", RegLine."Unit of Measure Code");
        ItemJnlLine.Validate(Quantity, RegLine.Quantity);

        ItemJnlLine.Insert(true);
    end;

    local procedure AttachItemTracking(ItemJnlLine: Record "Item Journal Line"; RegLine: Record "Registered Whse. Activity Line")
    var
        TempReservEntry: Record "Reservation Entry";
        ReservEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservStatus: Enum "Reservation Status";
    begin
        TempReservEntry.Init();
        TempReservEntry."Lot No." := RegLine."Lot No.";
        TempReservEntry."Package No." := RegLine."Package No.";
        if RegLine."Expiration Date" <> 0D then
            TempReservEntry."Expiration Date" := RegLine."Expiration Date";

        CreateReservEntry.CreateReservEntryFor(
            Database::"Item Journal Line",
            ItemJnlLine."Entry Type".AsInteger(),
            ItemJnlLine."Journal Template Name",
            ItemJnlLine."Journal Batch Name",
            0,
            ItemJnlLine."Line No.",
            ItemJnlLine."Qty. per Unit of Measure",
            ItemJnlLine.Quantity,
            ItemJnlLine."Quantity (Base)",
            TempReservEntry);
        CreateReservEntry.SetDates(0D, RegLine."Expiration Date");
        CreateReservEntry.CreateEntry(
            ItemJnlLine."Item No.",
            ItemJnlLine."Variant Code",
            ItemJnlLine."Location Code",
            '',
            0D,
            0D,
            0,
            ReservStatus::Surplus);

        // Back-fill the "New" tracking on the entry just created: keep the lot
        // and expiry, swap Package No. -> Pallet No.
        ReservEntry.SetRange("Source Type", Database::"Item Journal Line");
        ReservEntry.SetRange("Source Subtype", ItemJnlLine."Entry Type".AsInteger());
        ReservEntry.SetRange("Source ID", ItemJnlLine."Journal Template Name");
        ReservEntry.SetRange("Source Batch Name", ItemJnlLine."Journal Batch Name");
        ReservEntry.SetRange("Source Ref. No.", ItemJnlLine."Line No.");
        ReservEntry.SetRange("Lot No.", RegLine."Lot No.");
        if ReservEntry.FindLast() then begin
            ReservEntry."New Lot No." := RegLine."Lot No.";
            ReservEntry."Package No." := RegLine."Package No.";
            ReservEntry."New Package No." := RegLine."Pallet No.";
            if RegLine."Expiration Date" <> 0D then
                ReservEntry."New Expiration Date" := RegLine."Expiration Date";
            ReservEntry.Modify();
        end;
    end;

    var
        NotPutAwayErr: Label 'Pallet reclassification only applies to Put-away documents.';
        AlreadyReclassifiedErr: Label 'There are no put-away lines left to reclassify on this document. The Pallet No. reclassification has already been posted.';
        NoTransferTemplateErr: Label 'No Item Journal Template of type Transfer (Reclassification) was found. Configure one before posting the pallet reclassification.';
        ReclassPostedMsg: Label 'Pallet No. reclassification posted for registered put-away %1.', Comment = '%1 = Registered Put-away No.';
        BatchNameTok: Label 'PALLETRCL', Locked = true;
        BatchDescLbl: Label 'Pallet No. Reclassification';
}
