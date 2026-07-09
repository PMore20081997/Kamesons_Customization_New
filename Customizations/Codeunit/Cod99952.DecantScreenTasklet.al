namespace Kamesons_Customization.Kamesons_Customization;


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
        DefaultToBin: Code[20];
    begin
        if not (_RegistrationType in ['DecantItemReg', 'DecantScreenLookup']) then
            exit;

        DefaultToBin := CopyStr(_HeaderFieldValues.GetValue('ToBinCode'), 1, MaxStrLen(DefaultToBin));

        _Steps.Create_TextStep(1, 'ToBinCode', 'Scan To Bin Code');
        if DefaultToBin <> '' then begin
            _Steps.Set_DefaultValue(DefaultToBin);
            _Steps.Set_helpLabel('Expected: ' + DefaultToBin);
        end;
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
    begin
        if _IsHandled then
            exit;
        if _RegistrationType <> 'DecantItemReg' then
            exit;

        // if _RequestValues.GetValue('Confirm') <> 'Yes' then
        //     Error(PostingCancelledTok);

        TemplateName := CopyStr(_RequestValues.GetValue('Template'), 1, MaxStrLen(TemplateName));
        BatchName := CopyStr(_RequestValues.GetValue('Batch'), 1, MaxStrLen(BatchName));
        LineNo := _RequestValues.GetValueAsInteger('LineNumber');
        ToBinCode := CopyStr(_RequestValues.GetValue('ToBinCode'), 1, MaxStrLen(ToBinCode));

        DecantPostMgt.PostSingleDecantLine(TemplateName, BatchName, LineNo, ToBinCode, '');

        //_SuccessMessage := MobWmsLanguage.GetMessage('POST_SUCCESS');
        _SuccessMessage := 'Record posted successfully.';
        _RegistrationTypeTracking := StrSubstNo('%1|%2|%3', TemplateName, BatchName, LineNo);
        _IsHandled := true;
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