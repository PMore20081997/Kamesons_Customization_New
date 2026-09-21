namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using System.Text;


// -------------------------------------------------------------------------------------
// Decant Screen on Tasklet Mobile WMS — "Lookup + Unplanned" pattern.
//
//   Lookup page  (DecantScreen)    -> shows Decant Details rows filtered by
//                                     Batch / Location / Item No. Operator scans
//                                     filters, taps Accept, taps a row.
//   Unplanned    (DecantItemReg)   -> two scan steps: To Bin Code and New Package No.
//                                     On post, the line is updated and the Item Reclass
//                                     Journal entry is created + posted via
//                                     Cod99956 "Decant Tasklet Post Mgt.".
//
// Carrier values transferred from Lookup row to Unplanned page (via matching
// header field names): Template, Batch, LocationCode, ItemNo, LineNumber.
//
// IMPORTANT: This codeunit uses Tasklet's built-in Lookup / PostAdhocRegistration
// document types. No CreateDocumentType registration is required — and none of the
// custom GetDecantOrders / GetDecantOrderLines / PostDecantOrder doc types from
// the earlier OrderList pattern are needed any more.
// -------------------------------------------------------------------------------------

codeunit 99952 DecantScreenTasklet
{
    Access = Public;

    var
        DecantPostMgt: Codeunit "Decant Tasklet Post Mgt.";
        PostingCancelledTok: Label 'Posting cancelled.', Locked = true;
        KnappClientNumberTok: Label 'DEFAULT', Locked = true;
        KnappLoadCarrierTok: Label 'FULL', Locked = true;
        KnappDecantRequestTok: Label '{"clientNumber":"%1","orderNumber":"%2","targetPosition":{"storageArea":"%3"},"loadUnitCode":"%4","loadCarrier":"%5"}', Locked = true, Comment = '%1 = client, %2 = document no., %3 = storage area, %4 = load unit, %5 = load carrier';
        DirectControlEndpointTok: Label '/kisoft/oneapi/v1/directControl', Locked = true;
        KnappChannelCodeTok: Label 'KISOFT', Locked = true;
        KnappHttpErrorTok: Label '%1: %2', Locked = true, Comment = '%1 = HTTP status code, %2 = response body';
        KnappConnectionFailedTok: Label 'Connection failed. URL=%1. %2', Comment = '%1 = URL, %2 = last error text';
        MissingBaseURLErr: Label 'Base URL must be set in KiSoft Knapp Setup for channel %1.', Comment = '%1 = channel code';
        MissingKnappSetupErr: Label 'No KiSoft Knapp Setup found for channel %1.', Comment = '%1 = channel code';
        ExpectedValueTok: Label 'Expected: %1', Comment = '%1 = the value the operator is expected to scan';
        ToBinStepNameTok: Label 'ToBinCode_%1', Locked = true, Comment = '%1 = Decant Details Line No.';
        NewPackageStepNameTok: Label 'NewPackageNo_%1', Locked = true, Comment = '%1 = Decant Details Line No.';
        NoDecantLineErr: Label 'No decant line selected. Please pick a line from the Decant Screen.';
        BatchCompletedErr: Label 'All decant lines in this batch are posted. Please start a new decant.';
        MissingUsernameErr: Label 'Basic Auth Username must be set in KiSoft Knapp Setup.';
        MissingPasswordErr: Label 'Basic Auth Password must be set in KiSoft Knapp Setup.';

    // ---------- 1. Header configurations -------------------------------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Reference Data", 'OnGetReferenceData_OnAddHeaderConfigurations', '', true, true)]
    local procedure OnAddHeaderConfigurations_Decant(var _HeaderFields: Record "MOB HeaderField Element")
    begin
        // Decant Screen lookup filters (visible to operator)
        _HeaderFields.InitConfigurationKey('DecantScreenLookup');

        // Package No. — operator scans or enters the package to filter Decant Details.
        _HeaderFields.Create_TextField(1, 'PackageNo', 'Package No.:');
        _HeaderFields.Set_optional(true);

        // Hidden carriers passed from the lookup row to the per-line registration.
        _HeaderFields.InitConfigurationKey('DecantItemReg');
        _HeaderFields.Create_TextField(1, 'Template', 'Template:');
        _HeaderFields.Set_visible(false);
        _HeaderFields.Create_TextField(2, 'Batch', 'Batch:');
        _HeaderFields.Set_visible(false);
        _HeaderFields.Create_TextField(3, 'LocationCode', 'Location:');
        _HeaderFields.Set_visible(false);
        _HeaderFields.Create_TextField(4, 'ItemNo', 'Item No.:');
        _HeaderFields.Set_locked(true);
        _HeaderFields.Create_TextField(5, 'Description', 'Description:');
        _HeaderFields.Set_locked(true);
        _HeaderFields.Create_TextField(6, 'LineNumber', 'Line No.:');
        _HeaderFields.Set_visible(false);
        _HeaderFields.Create_TextField(7, 'ToBinCode', 'To Bin Code:');
        _HeaderFields.Set_visible(false);
        // AutoSave=false + a single Save() — the 3-parameter Create_TextField
        // overload implies AutoSave=true, which writes the field before
        // Set_visible runs, so the carrier is not declared as the others are.
        _HeaderFields.Create_TextField(8, 'NewPackageNo', false);
        _HeaderFields.Set_label('New Package No.:');
        _HeaderFields.Set_visible(false);
        _HeaderFields.Set_length(20);
        _HeaderFields.Save();
    end;

    // ---------- 2. Lookup: list Decant Details for the chosen filters --------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Lookup", 'OnLookupOnCustomLookupType', '', true, true)]
    local procedure OnLookupOnCustomLookupType_Decant(_MessageId: Guid; _LookupType: Text; var _RequestValues: Record "MOB NS Request Element"; var _LookupResponseElement: Record "MOB NS WhseInquery Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        DecantDetails: Record "Decant Details";
        PackageFilter: Text;
    begin
        if _IsHandled then
            exit;
        if _LookupType <> 'DecantScreenLookup' then
            exit;

        PackageFilter := _RequestValues.GetValue('PackageNo');

        if PackageFilter <> '' then
            DecantDetails.SetFilter("Package No.", PackageFilter);

        // Only list lines that have a New Package No. assigned.
        DecantDetails.SetFilter("New Package No.", '<>%1', '');

        if DecantDetails.FindSet() then
            repeat
                _LookupResponseElement.Create();

                // Carrier values — these flow to the DecantItemReg page because
                // both header configurations declare these same field names.
                _LookupResponseElement.SetValue('Template', DecantDetails."Journal Template Name");
                _LookupResponseElement.SetValue('Batch', DecantDetails."Journal Batch Name");
                _LookupResponseElement.SetValue('LocationCode', DecantDetails."Location Code");
                _LookupResponseElement.SetValue('ItemNo', DecantDetails."Item No.");
                _LookupResponseElement.SetValue('Description', DecantDetails.Description);
                _LookupResponseElement.SetValue('LineNumber', Format(DecantDetails."Line No."));
                _LookupResponseElement.SetValue('ToBinCode', DecantDetails."To Bin Code");
                _LookupResponseElement.SetValue('NewPackageNo', DecantDetails."New Package No.");

                // What the operator sees on each list row.
                _LookupResponseElement.Set_DisplayLine1(BuildNewPackageLine(DecantDetails));
                _LookupResponseElement.Set_DisplayLine2(BuildBinLine(DecantDetails));
                _LookupResponseElement.Set_DisplayLine3(DecantDetails."Item No.");
                _LookupResponseElement.Set_DisplayLine4(DecantDetails.Description);
                _LookupResponseElement.Set_DisplayLine5(BuildLotExpiryLine(DecantDetails));



                // Right-hand column on the LookupWithRegistrations list shows
                // "{Quantity}/{ExtraInfo1}" — fill both with the line's qty and UoM.
                _LookupResponseElement.Set_Quantity(Format(DecantDetails.Quantity));
                _LookupResponseElement.Set_ExtraInfo1(DecantDetails."Unit of Measure Code");
            until DecantDetails.Next() = 0;

        _IsHandled := true;
    end;

    // ---------- 2b. Lookup data for header fields (Batch / Location / Item) -

    /// <summary>
    /// Provides the dropdown contents when the operator taps the lookup icon on
    /// one of the three Decant Screen header fields. The fieldName-matched
    /// branches return distinct values pulled from Decant Details (so the lists
    /// only show data the operator can actually pick).
    ///
    /// NOTE: Tasklet event names for header-field lookups vary by version. If
    /// 'OnLookupOnCustomLookupType' isn't invoked for header-field lookups in
    /// your build, the equivalent event in your Tasklet version is the one to
    /// hook (look on Codeunit "MOB WMS Lookup" for an event name with "Header"
    /// or "Filter" in it).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Lookup", 'OnLookupOnCustomLookupType', '', true, true)]
    local procedure OnLookupOnCustomLookupType_DecantHeaderFields(_MessageId: Guid; _LookupType: Text; var _RequestValues: Record "MOB NS Request Element"; var _LookupResponseElement: Record "MOB NS WhseInquery Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    begin
        if _IsHandled then
            exit;

        if _LookupType = 'DecantScreenLookup.PackageNo' then begin
            BuildPackageNoLookup(_LookupResponseElement);
            _IsHandled := true;
        end;
    end;

    local procedure BuildPackageNoLookup(var _LookupResponseElement: Record "MOB NS WhseInquery Element")
    var
        DecantDetails: Record "Decant Details";
        SeenPackages: List of [Code[50]];
    begin
        if DecantDetails.FindSet() then
            repeat
                if (DecantDetails."Package No." <> '') and not SeenPackages.Contains(DecantDetails."Package No.") then begin
                    SeenPackages.Add(DecantDetails."Package No.");
                    _LookupResponseElement.Create();
                    _LookupResponseElement.SetValue('Value', DecantDetails."Package No.");
                    _LookupResponseElement.Set_DisplayLine1(DecantDetails."Package No.");
                    _LookupResponseElement.Set_DisplayLine2(DecantDetails."Item No." + '  ' + DecantDetails.Description);
                end;
            until DecantDetails.Next() = 0;
    end;

    // ---------- 3. Registration steps: To Bin Code, New Package No. ---------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnGetRegistrationConfiguration_OnAddSteps', '', true, true)]
    local procedure OnAddSteps_DecantItemReg(_RegistrationType: Text; var _HeaderFieldValues: Record "MOB NS Request Element"; var _Steps: Record "MOB Steps Element"; var _RegistrationTypeTracking: Text)
    var
        DecantDetails: Record "Decant Details";
        DefaultToBin: Code[20];
        DefaultNewPackageNo: Code[20];
    begin
        if not (_RegistrationType in ['DecantItemReg', 'DecantScreenLookup']) then
            exit;

        // After a post the line is deleted, but the device keeps the old header
        // values and re-opens this screen on Accept. Resolve the line the header
        // points at — falling forward to the next open line, or erroring out when
        // the batch is finished — so the operator can never post a stale line.
        ResolveTargetDecantLine(_HeaderFieldValues, DecantDetails);

        DefaultToBin := DecantDetails."To Bin Code";
        DefaultNewPackageNo := DecantDetails."New Package No.";

        // The device caches the rendered control per step name, so re-opening
        // this screen after a post reuses the previous line's input box and help
        // label. Suffixing the name with the line number makes every line a new
        // control, which forces a clean render.
        _Steps.Create_TextStep(1, StrSubstNo(ToBinStepNameTok, DecantDetails."Line No."), 'Scan To Bin Code', 'To Bin Code:', BuildExpectedLabel(DefaultToBin), DefaultToBin, 20);

        // Steps are ordered by step id, so id 2 places this directly after
        // "Scan To Bin Code". The scanned value arrives in the posting handler
        // through _RequestValues, same as ToBinCode.
        _Steps.Create_TextStep(2, StrSubstNo(NewPackageStepNameTok, DecantDetails."Line No."), 'Scan New Package No.', 'New Package No.:', BuildExpectedLabel(DefaultNewPackageNo), DefaultNewPackageNo, 20);
    end;

    /// <summary>
    /// Builds the "Expected: X" help label, or '' when there is no value to
    /// show — keeps the empty case out of the step-building calls.
    /// </summary>
    local procedure BuildExpectedLabel(_Value: Code[20]): Text
    begin
        if _Value = '' then
            exit('');
        exit(StrSubstNo(ExpectedValueTok, _Value));
    end;

    /// <summary>
    /// Resolves which Decant Details line this registration should work on.
    ///
    /// Normally that is the line the header carriers point at. After a post the
    /// line is deleted, but the device keeps the old header values and re-opens
    /// the screen when the operator taps Accept — so a missing line means "the
    /// carried line is already posted". In that case fall forward to the next
    /// open line in the same batch, and error out when there is none left, which
    /// aborts the configuration and returns the operator to the start screen.
    ///
    /// On return the header carriers are rewritten to the resolved line, so the
    /// posting handler (which reads the same values) targets the line the
    /// operator is actually shown.
    /// </summary>
    local procedure ResolveTargetDecantLine(var _HeaderFieldValues: Record "MOB NS Request Element"; var _DecantDetails: Record "Decant Details")
    var
        TemplateName: Code[10];
        BatchName: Code[10];
        LineNo: Integer;
    begin
        TemplateName := CopyStr(_HeaderFieldValues.GetValue('Template'), 1, MaxStrLen(TemplateName));
        BatchName := CopyStr(_HeaderFieldValues.GetValue('Batch'), 1, MaxStrLen(BatchName));
        LineNo := _HeaderFieldValues.GetValueAsInteger('LineNumber');

        _DecantDetails.Reset();

        // Template / Batch are hidden carriers and the device does not always
        // echo them back on this request, so scope by them only when present.
        // Without them the fall-forward still works, just batch-wide.
        if TemplateName <> '' then
            _DecantDetails.SetRange("Journal Template Name", TemplateName);
        if BatchName <> '' then
            _DecantDetails.SetRange("Journal Batch Name", BatchName);

        // The carried line, if it is still open.
        if LineNo <> 0 then begin
            _DecantDetails.SetRange("Line No.", LineNo);
            if _DecantDetails.FindFirst() then
                exit;
            _DecantDetails.SetRange("Line No.");
        end;

        // Already posted (or no line carried) — move on to the next open line.
        // Only lines with a New Package No. are offered, matching the lookup's
        // own filter.
        if LineNo <> 0 then
            _DecantDetails.SetFilter("Line No.", '>%1', LineNo);
        _DecantDetails.SetFilter("New Package No.", '<>%1', '');

        // Nothing after the posted line — wrap round to the first open line, so
        // finishing the last line in a batch does not strand earlier ones.
        if not _DecantDetails.FindFirst() then begin
            _DecantDetails.SetRange("Line No.");
            if not _DecantDetails.FindFirst() then
                Error(BatchCompletedErr);
        end;

        RefreshLineCarriers(_HeaderFieldValues, _DecantDetails);
    end;

    /// <summary>
    /// Rewrites the header carriers onto the given line, so every later reader
    /// of _HeaderFieldValues / _RequestValues sees the resolved line rather than
    /// the one the device sent.
    /// </summary>
    local procedure RefreshLineCarriers(var _HeaderFieldValues: Record "MOB NS Request Element"; var _DecantDetails: Record "Decant Details")
    begin
        _HeaderFieldValues.SetValue('LineNumber', Format(_DecantDetails."Line No."));
        _HeaderFieldValues.SetValue('ItemNo', _DecantDetails."Item No.");
        _HeaderFieldValues.SetValue('Description', _DecantDetails.Description);
        _HeaderFieldValues.SetValue('LocationCode', _DecantDetails."Location Code");
        _HeaderFieldValues.SetValue('ToBinCode', _DecantDetails."To Bin Code");
        _HeaderFieldValues.SetValue('NewPackageNo', _DecantDetails."New Package No.");
    end;

    // ---------- 3b. Radio-button confirmation injected after operator taps ✓ ---

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistration_OnAddSteps', '', true, true)]
    // local procedure OnPostAddSteps_DecantConfirm(_RegistrationType: Text; var _RequestValues: Record "MOB NS Request Element"; var _Steps: Record "MOB Steps Element"; var _RegistrationTypeTracking: Text)
    // begin
    //     if _RegistrationType <> 'DecantItemReg' then
    //         exit;
    //     // Only inject on first pass — once Confirm is answered, proceed to post.
    //     if _RequestValues.GetValue('Confirm') <> '' then
    //         exit;
    //     _Steps.Create_RadioButtonStep_YesNo(1, 'Confirm', 'Post this decant line?', '');
    // end;

    // ---------- 4. Post: save scans + run Item Reclass for this single line --

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistrationOnCustomRegistrationType', '', true, true)]
    local procedure OnPostAdhocRegistration_DecantItemReg(_MessageId: Guid; _RegistrationType: Text; var _RequestValues: Record "MOB NS Request Element"; var _CurrentRegistrations: Record "MOB WMS Registration"; var _Commands: Record "MOB Command Element"; var _SuccessMessage: Text; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        MobWmsLanguage: Codeunit "MOB WMS Language";
        TemplateName: Code[10];
        BatchName: Code[10];
        LineNo: Integer;
        ToBinCode: Code[20];
        NewPackageNo: Code[20];
    begin
        if _IsHandled then
            exit;
        if _RegistrationType <> 'DecantItemReg' then
            exit;

        // if _RequestValues.GetValue('Confirm') <> 'Yes' then
        //     Error(PostingCancelledTok);

        TemplateName := CopyStr(_RequestValues.GetValue('Template'), 1, MaxStrLen(TemplateName));
        BatchName := CopyStr(_RequestValues.GetValue('Batch'), 1, MaxStrLen(BatchName));
        // The device sends back its own cached LineNumber, which after a post is
        // the line that was just deleted. The step names carry the line the steps
        // were actually built for, so trust those instead and fall back to the
        // header value only when no suffixed step is present.
        LineNo := GetPostedLineNo(_RequestValues);
        if LineNo = 0 then
            LineNo := _RequestValues.GetValueAsInteger('LineNumber');

        ToBinCode := CopyStr(_RequestValues.GetValue(StrSubstNo(ToBinStepNameTok, LineNo)), 1, MaxStrLen(ToBinCode));
        if ToBinCode = '' then
            ToBinCode := CopyStr(_RequestValues.GetValue('ToBinCode'), 1, MaxStrLen(ToBinCode));

        NewPackageNo := CopyStr(_RequestValues.GetValue(StrSubstNo(NewPackageStepNameTok, LineNo)), 1, MaxStrLen(NewPackageNo));
        if NewPackageNo = '' then
            NewPackageNo := CopyStr(_RequestValues.GetValue('NewPackageNo'), 1, MaxStrLen(NewPackageNo));

        DecantPostMgt.PostSingleDecantLine(TemplateName, BatchName, LineNo, ToBinCode, NewPackageNo);

        //_SuccessMessage := MobWmsLanguage.GetMessage('POST_SUCCESS');
        _SuccessMessage := 'Record posted successfully.';
        _RegistrationTypeTracking := StrSubstNo('%1|%2|%3', TemplateName, BatchName, LineNo);
        _IsHandled := true;
    end;

    /// <summary>
    /// Recovers the Decant Details line number from the registration's step
    /// names. Steps are created as "NewPackageNo_&lt;LineNo&gt;", so the suffix on
    /// the element the device sent back identifies the line the operator was
    /// actually shown — unlike the LineNumber header, which the device caches
    /// and still reports as the previously posted line.
    /// Returns 0 when no suffixed step is present.
    /// </summary>
    local procedure GetPostedLineNo(var _RequestValues: Record "MOB NS Request Element"): Integer
    var
        Element: Record "MOB NS Request Element" temporary;
        NamePrefix: Text;
        Suffix: Text;
        LineNo: Integer;
    begin
        // Work on a copy — the caller keeps reading values off _RequestValues,
        // so its cursor and filters must not move. Both records must be
        // temporary for Copy(..., true) to share the underlying table.
        Element.Copy(_RequestValues, true);
        Element.Reset();
        if not Element.FindSet() then
            exit(0);

        NamePrefix := StrSubstNo(NewPackageStepNameTok, '');

        repeat
            if StrPos(Element.Name, NamePrefix) = 1 then begin
                Suffix := CopyStr(Element.Name, StrLen(NamePrefix) + 1);
                if Evaluate(LineNo, Suffix) then
                    exit(LineNo);
            end;
        until Element.Next() = 0;

        exit(0);
    end;

    // ---------- 5. KNAPP: build payload + queue record after posting ----------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Decant Tasklet Post Mgt.", 'OnAfterPostSingleDecantLine', '', true, true)]
    local procedure OnAfterPostSingleDecantLine_CreateKnappQueue(var DecantDetails: Record "Decant Details"; ReclassTemplateName: Code[10]; ReclassBatchName: Code[10]; DocNo: Code[20])
    var
        L_Item: Record Item;
        KnappRequest: Text;
    begin
        // Only KNAPP-flagged items are routed to the KNAPP system — everything else
        // is a normal decant and needs no payload or queue entry.

        if not L_Item.Get(DecantDetails."Item No.") then
            exit;
        if L_Item."Knapp Item" = false then
            exit;
        KnappRequest := BuildKnappDecantRequest(DecantDetails, DocNo);

        if KnappRequest = '' then
            exit;

        CreateKnappDocumentQueueEntry(KnappRequest, DocNo);

        SendQueuedDirectControls();
    end;

    /// <summary>
    /// Pushes the queued Direct Control requests to KNAPP without letting a
    /// KNAPP problem fail the decant that has already been posted.
    ///
    /// Commit() hardens the queue row first — the HTTP call needs the write
    /// transaction closed, and the row must survive even if the send fails.
    /// Codeunit.Run() then swallows any error, leaving the row in status New
    /// so the next run (or the "Sync Direct Control to KiSoft" action on the
    /// Knapp Document Queue page) retries it.
    /// </summary>
    local procedure SendQueuedDirectControls()
    var
        KnappDirectControlSender: Codeunit "Knapp Direct Control Sender";
    begin
        Commit();

        KnappDirectControlSender.SetChannelCode(KnappChannelCodeTok);
        if not KnappDirectControlSender.Run() then
            ClearLastError();
    end;

    /// <summary>
    /// Inserts the built request into the Knapp Document Queue so the KNAPP
    /// integration picks it up on its next run.
    /// </summary>
    local procedure CreateKnappDocumentQueueEntry(KnappRequest: Text; DocNo: Code[20])
    var
        G_KnappDocumentQueue: Record "Knapp Document Queue";
        Rec_KnappDocumentQueue: Record "Knapp Document Queue";
        OStream: OutStream;
    begin
        Clear(G_KnappDocumentQueue);
        G_KnappDocumentQueue.Reset();
        G_KnappDocumentQueue.Init();

        Rec_KnappDocumentQueue.Reset();
        Rec_KnappDocumentQueue.SetRange("Document Type", Rec_KnappDocumentQueue."Document Type"::"Direct Control");
        if Rec_KnappDocumentQueue.FindLast() then
            G_KnappDocumentQueue."Entry No." := Rec_KnappDocumentQueue."Entry No." + 1
        else
            G_KnappDocumentQueue."Entry No." := 1;

        G_KnappDocumentQueue."User ID" := UserId;
        G_KnappDocumentQueue."Document Type" := G_KnappDocumentQueue."Document Type"::"Direct Control";
        G_KnappDocumentQueue.Status := G_KnappDocumentQueue.Status::New;
        G_KnappDocumentQueue."Created Date/Time" := CurrentDateTime;
        Clear(OStream);
        G_KnappDocumentQueue.Request.CreateOutStream(OStream, TextEncoding::UTF8);
        OStream.WriteText(KnappRequest);
        G_KnappDocumentQueue."Document Reference No." := DocNo;
        G_KnappDocumentQueue.Insert();
    end;

    /// <summary>
    /// Builds the KNAPP goods-in request for one posted decant line, e.g.
    /// {"clientNumber":"DEFAULT","orderNumber":"RT050","targetPosition":{"storageArea":"M006"},
    ///  "loadUnitCode":"211748","loadCarrier":"FULL"}
    /// Returns '' when no Knapp Item Details row matches the item / To Bin Code,
    /// so the caller can skip queueing a request KNAPP cannot route.
    /// </summary>
    local procedure BuildKnappDecantRequest(var DecantDetails: Record "Decant Details"; DocNo: Code[20]) KnappRequest: Text
    var
        KnappItemDetails: Record "Knapp Item Details";
        StorageArea: Text;
    begin
        // Caller has already confirmed the item is a KNAPP item.
        // targetPosition.storageArea — the replenishment location configured for this
        // item at the bin the decanted tote was just moved into.
        // Priority 1 — match the To Bin Code against "Overstock Storage Location".
        // Priority 2 — when no such row exists (the item has no overstock location
        // set up), fall back to matching on "Knapp Storage Location" instead.
        if not FindKnappItemDetailsByLocation(DecantDetails, KnappItemDetails, KnappItemDetails.FieldNo("Overstock Storage Location")) then
            if not FindKnappItemDetailsByLocation(DecantDetails, KnappItemDetails, KnappItemDetails.FieldNo("Knapp Storage Location")) then
                exit('');

        StorageArea := KnappItemDetails."Replenishment Storage Location";
        if StorageArea = '' then
            exit('');

        KnappRequest :=
            StrSubstNo(
                KnappDecantRequestTok,
                KnappClientNumberTok, DocNo, StorageArea, DecantDetails."New Package No.", KnappLoadCarrierTok);
    end;

    /// <summary>
    /// Finds the Knapp Item Details row for the decanted item, matching the
    /// line's To Bin Code against the storage-location field identified by
    /// LocationFieldNo ("Overstock Storage Location" or "Knapp Storage
    /// Location"). Returns false when no row matches, so the caller can try
    /// the next field in priority order.
    /// </summary>
    local procedure FindKnappItemDetailsByLocation(var DecantDetails: Record "Decant Details"; var KnappItemDetails: Record "Knapp Item Details"; LocationFieldNo: Integer): Boolean
    begin
        if DecantDetails."To Bin Code" = '' then
            exit(false);

        // "Item Barcode" is a FlowField (lookup on Item Reference) — without
        // CalcFields it reads as '' and the filter below would match nothing.
        DecantDetails.CalcFields("Item Barcode");

        KnappItemDetails.Reset();
        KnappItemDetails.SetRange("Item No.", DecantDetails."Item No.");
        KnappItemDetails.SetFilter("Item Reference No.", '%1', DecantDetails."Item Barcode");

        // A blank location on the row is not a match — it would otherwise let an
        // unconfigured row satisfy the Overstock pass and hide the Knapp fallback.
        case LocationFieldNo of
            KnappItemDetails.FieldNo("Overstock Storage Location"):
                KnappItemDetails.SetFilter("Overstock Storage Location", '%1', DecantDetails."To Bin Code");
            KnappItemDetails.FieldNo("Knapp Storage Location"):
                KnappItemDetails.SetFilter("Knapp Storage Location", '%1', DecantDetails."To Bin Code");
            else
                exit(false);
        end;

        exit(KnappItemDetails.FindFirst());
    end;

    // ---------- 6. KNAPP: send queued Direct Control requests -----------------

    /// <summary>
    /// Drains the Knapp Document Queue of pending Direct Control requests and
    /// POSTs each one to KNAPP, stamping the outcome back onto the queue row.
    /// Mirrors KiSoftIntegration.CreateOrder / CreateDirectControls — safe to
    /// call from a Job Queue entry.
    /// </summary>
    procedure SendDirectControlsToKnapp(ChannelCode: Code[20])
    var
        KnappDocumentQueue: Record "Knapp Document Queue";
        Client: HttpClient;
        Content: HttpContent;
        Headers: HttpHeaders;
        ResponseMessage: HttpResponseMessage;
        IStream: InStream;
        ServiceURL: Text;
        URL: Text;
        Body: Text;
        Response: Text;
    begin
        ServiceURL := GetKnappServiceURL(ChannelCode);
        if ServiceURL = '' then
            Error(MissingBaseURLErr, ChannelCode);

        URL := ServiceURL + DirectControlEndpointTok;

        KnappDocumentQueue.Reset();
        KnappDocumentQueue.SetRange("Document Type", KnappDocumentQueue."Document Type"::"Direct Control");
        KnappDocumentQueue.SetRange(Status, KnappDocumentQueue.Status::New);
        if not KnappDocumentQueue.FindSet() then
            exit;

        repeat
            // Fresh client per row — headers accumulate on a reused HttpClient.
            Clear(Client);
            Clear(Content);
            Headers.Clear();
            Headers := Client.DefaultRequestHeaders();
            Headers.Add('Authorization', BuildKnappBasicAuthHeader(ChannelCode));
            Headers.Add('accept', 'application/json');
            Headers.Add('charset', 'UTF-8');

            // Request is a Blob — CalcFields is required, FindSet does not load it.
            Clear(IStream);
            Clear(Body);
            KnappDocumentQueue.CalcFields(Request);
            KnappDocumentQueue.Request.CreateInStream(IStream, TextEncoding::UTF8);
            IStream.ReadText(Body);

            Content.WriteFrom(Body);
            Content.GetHeaders(Headers);
            // HttpContent sets its own Content-Type — it must be removed before ours is added.
            Headers.Remove('Content-Type');
            Headers.Add('Content-Type', 'application/json');

            Clear(Response);
            if Client.Post(URL, Content, ResponseMessage) then begin
                ResponseMessage.Content().ReadAs(Response);
                if ResponseMessage.HttpStatusCode() = 200 then begin
                    KnappDocumentQueue.Status := KnappDocumentQueue.Status::Completed;
                    KnappDocumentQueue.Response := '';
                end else begin
                    KnappDocumentQueue.Status := KnappDocumentQueue.Status::Error;
                    KnappDocumentQueue.Response :=
                        CopyStr(StrSubstNo(KnappHttpErrorTok, ResponseMessage.HttpStatusCode(), Response), 1, MaxStrLen(KnappDocumentQueue.Response));
                end;
            end else begin
                KnappDocumentQueue.Status := KnappDocumentQueue.Status::Error;
                KnappDocumentQueue.Response :=
                    CopyStr(StrSubstNo(KnappConnectionFailedTok, URL, GetLastErrorText()), 1, MaxStrLen(KnappDocumentQueue.Response));
            end;

            KnappDocumentQueue."Updated Date/Time" := CurrentDateTime();
            KnappDocumentQueue.Modify();
        until KnappDocumentQueue.Next() = 0;
    end;

    local procedure GetKnappServiceURL(ChannelCode: Code[20]): Text
    var
        KiSoftKnappSetup: Record "KiSoft Knapp Setup";
    begin
        if KiSoftKnappSetup.Get(ChannelCode) then
            exit(KiSoftKnappSetup."Base URL");
        exit('');
    end;

    /// <summary>
    /// Basic auth header for the KNAPP channel. KiSoftIntegration's own
    /// BuildBasicAuthHeader is local to that codeunit, so it is repeated here.
    /// </summary>
    local procedure BuildKnappBasicAuthHeader(ChannelCode: Code[20]): Text
    var
        KiSoftKnappSetup: Record "KiSoft Knapp Setup";
        Base64Convert: Codeunit "Base64 Convert";
        Credentials: Text;
    begin
        if not KiSoftKnappSetup.Get(ChannelCode) then
            Error(MissingKnappSetupErr, ChannelCode);
        if KiSoftKnappSetup."Basic Auth Username" = '' then
            Error(MissingUsernameErr);
        if KiSoftKnappSetup."Basic Auth Password" = '' then
            Error(MissingPasswordErr);

        Credentials := KiSoftKnappSetup."Basic Auth Username" + ':' + KiSoftKnappSetup."Basic Auth Password";
        exit('Basic ' + Base64Convert.ToBase64(Credentials));
    end;

    // ---------- Helpers ------------------------------------------------------

    local procedure BuildLotExpiryLine(DecantDetails: Record "Decant Details"): Text
    var
        Result: Text;
    begin
        if DecantDetails."Lot No." <> '' then
            Result := 'Lot: ' + DecantDetails."Lot No.";
        if DecantDetails."Expiry Date" <> 0D then begin
            if Result <> '' then
                Result += '  ';
            Result += 'Exp: ' + Format(DecantDetails."Expiry Date");
        end;
        exit(Result);
    end;

    local procedure BuildBinLine(DecantDetails: Record "Decant Details"): Text
    begin
        exit('To: ' + DecantDetails."To Bin Code");
    end;

    local procedure BuildNewPackageLine(DecantDetails: Record "Decant Details"): Text
    begin
        if DecantDetails."New Package No." = '' then
            exit('');
        exit('PKG: ' + DecantDetails."New Package No.");
    end;

}
