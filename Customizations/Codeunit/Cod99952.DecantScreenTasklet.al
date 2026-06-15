namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Journal;

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
        SetupLookup: Codeunit "Kam Whse Setup Lookup";
        PostedOkMsgTok: Label 'Posted successfully.';
        DefaultBatchNameTok: Label 'DEFAULT', Locked = true;

    // ---------- 1. Header configurations -------------------------------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Reference Data", 'OnGetReferenceData_OnAddHeaderConfigurations', '', true, true)]
    local procedure OnAddHeaderConfigurations_Decant(var _HeaderFields: Record "MOB HeaderField Element")
    var
        ReceiveLocation: Code[20];
    begin
        ReceiveLocation := SetupLookup.GetReceiveLocation();

        // Decant Screen lookup filters (visible to operator)
        _HeaderFields.InitConfigurationKey('DecantScreenLookup');

        // Batch — default 'DEFAULT'.
        _HeaderFields.Create_TextField(1, 'Batch', 'Batch:');
        _HeaderFields.Set_DefaultValue(DefaultBatchNameTok);

        // Location Code — default = Receive Location from Warehouse Setup.
        _HeaderFields.Create_TextField(2, 'LocationCode', 'Location Code:');
        if ReceiveLocation <> '' then
            _HeaderFields.Set_DefaultValue(ReceiveLocation);

        // Item No. — optional; operator can leave blank to see all items in the batch.
        _HeaderFields.Create_TextField(3, 'ItemNo', 'Item No.:');
        _HeaderFields.Set_optional(true);

        // Hidden carriers passed from the lookup row to the per-line registration.
        // Field names must match the SetValue keys used in OnLookupOnCustomLookupType.
        _HeaderFields.InitConfigurationKey('DecantItemReg');
        _HeaderFields.Create_TextField(1, 'Template', 'Template:');
        _HeaderFields.Set_locked(true);
        _HeaderFields.Create_TextField(2, 'Batch', 'Batch:');
        _HeaderFields.Set_locked(true);
        _HeaderFields.Create_TextField(3, 'LocationCode', 'Location:');
        _HeaderFields.Set_locked(true);
        _HeaderFields.Create_TextField(4, 'ItemNo', 'Item No.:');
        _HeaderFields.Set_locked(true);
        _HeaderFields.Create_TextField(5, 'LineNumber', 'Line No.:');
        _HeaderFields.Set_locked(true);
    end;

    // ---------- 2. Lookup: list Decant Details for the chosen filters --------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Lookup", 'OnLookupOnCustomLookupType', '', true, true)]
    local procedure OnLookupOnCustomLookupType_Decant(_MessageId: Guid; _LookupType: Text; var _RequestValues: Record "MOB NS Request Element"; var _LookupResponseElement: Record "MOB NS WhseInquery Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        DecantDetails: Record "Decant Details";
        BatchFilter: Text;
        LocationFilter: Text;
        ItemFilter: Text;
    begin
        if _IsHandled then
            exit;
        if _LookupType <> 'DecantScreenLookup' then
            exit;

        BatchFilter := _RequestValues.GetValue('Batch');
        LocationFilter := _RequestValues.GetValue('LocationCode');
        ItemFilter := _RequestValues.GetValue('ItemNo');

        if BatchFilter <> '' then
            DecantDetails.SetFilter("Journal Batch Name", BatchFilter);
        if LocationFilter <> '' then
            DecantDetails.SetFilter("Location Code", LocationFilter);
        if ItemFilter <> '' then
            DecantDetails.SetFilter("Item No.", ItemFilter);

        if DecantDetails.FindSet() then
            repeat
                _LookupResponseElement.Create();

                // Carrier values — these flow to the DecantItemReg page because
                // both header configurations declare these same field names.
                _LookupResponseElement.SetValue('Template', DecantDetails."Journal Template Name");
                _LookupResponseElement.SetValue('Batch', DecantDetails."Journal Batch Name");
                _LookupResponseElement.SetValue('LocationCode', DecantDetails."Location Code");
                _LookupResponseElement.SetValue('ItemNo', DecantDetails."Item No.");
                _LookupResponseElement.SetValue('LineNumber', Format(DecantDetails."Line No."));

                // What the operator sees on each list row.
                _LookupResponseElement.Set_DisplayLine1(DecantDetails."Item No." + '  ' + DecantDetails.Description);
                _LookupResponseElement.Set_DisplayLine2(BuildLotExpiryLine(DecantDetails));
                _LookupResponseElement.Set_DisplayLine3(BuildBinLine(DecantDetails));
                _LookupResponseElement.Set_DisplayLine4(BuildPackageLine(DecantDetails));

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
    var
        BatchFilter: Text;
        LocationFilter: Text;
    begin
        if _IsHandled then
            exit;

        case _LookupType of
            'DecantScreenLookup.Batch':
                begin
                    LocationFilter := _RequestValues.GetValue('LocationCode');
                    BuildBatchLookup(LocationFilter, _LookupResponseElement);
                    _IsHandled := true;
                end;
            'DecantScreenLookup.LocationCode':
                begin
                    BuildLocationLookup(_LookupResponseElement);
                    _IsHandled := true;
                end;
            'DecantScreenLookup.ItemNo':
                begin
                    BatchFilter := _RequestValues.GetValue('Batch');
                    LocationFilter := _RequestValues.GetValue('LocationCode');
                    BuildItemLookup(BatchFilter, LocationFilter, _LookupResponseElement);
                    _IsHandled := true;
                end;
        end;
    end;

    local procedure BuildBatchLookup(LocationFilter: Text; var _LookupResponseElement: Record "MOB NS WhseInquery Element")
    var
        DecantDetails: Record "Decant Details";
        WhseJnlBatch: Record "Warehouse Journal Batch";
        SeenBatches: List of [Code[10]];
    begin
        // Distinct Decant Details batches at the selected Location (if entered).
        // Falls back to all Warehouse Journal Batches if Decant has no rows yet.
        if LocationFilter <> '' then
            DecantDetails.SetFilter("Location Code", LocationFilter);
        if DecantDetails.FindSet() then
            repeat
                if not SeenBatches.Contains(DecantDetails."Journal Batch Name") then begin
                    SeenBatches.Add(DecantDetails."Journal Batch Name");
                    _LookupResponseElement.Create();
                    _LookupResponseElement.SetValue('Value', DecantDetails."Journal Batch Name");
                    _LookupResponseElement.Set_DisplayLine1(DecantDetails."Journal Batch Name");
                    _LookupResponseElement.Set_DisplayLine2('Template: ' + DecantDetails."Journal Template Name");
                end;
            until DecantDetails.Next() = 0;

        if SeenBatches.Count() = 0 then
            if WhseJnlBatch.FindSet() then
                repeat
                    _LookupResponseElement.Create();
                    _LookupResponseElement.SetValue('Value', WhseJnlBatch.Name);
                    _LookupResponseElement.Set_DisplayLine1(WhseJnlBatch.Name);
                    _LookupResponseElement.Set_DisplayLine2(WhseJnlBatch.Description);
                until WhseJnlBatch.Next() = 0;
    end;

    local procedure BuildLocationLookup(var _LookupResponseElement: Record "MOB NS WhseInquery Element")
    var
        Location: Record Location;
    begin
        if Location.FindSet() then
            repeat
                _LookupResponseElement.Create();
                _LookupResponseElement.SetValue('Value', Location.Code);
                _LookupResponseElement.Set_DisplayLine1(Location.Code);
                _LookupResponseElement.Set_DisplayLine2(Location.Name);
            until Location.Next() = 0;
    end;

    local procedure BuildItemLookup(BatchFilter: Text; LocationFilter: Text; var _LookupResponseElement: Record "MOB NS WhseInquery Element")
    var
        DecantDetails: Record "Decant Details";
        SeenItems: List of [Code[20]];
    begin
        // Distinct items on Decant Details for the selected Batch + Location.
        if BatchFilter <> '' then
            DecantDetails.SetFilter("Journal Batch Name", BatchFilter);
        if LocationFilter <> '' then
            DecantDetails.SetFilter("Location Code", LocationFilter);
        if DecantDetails.FindSet() then
            repeat
                if not SeenItems.Contains(DecantDetails."Item No.") then begin
                    SeenItems.Add(DecantDetails."Item No.");
                    _LookupResponseElement.Create();
                    _LookupResponseElement.SetValue('Value', DecantDetails."Item No.");
                    _LookupResponseElement.Set_DisplayLine1(DecantDetails."Item No.");
                    _LookupResponseElement.Set_DisplayLine2(DecantDetails.Description);
                end;
            until DecantDetails.Next() = 0;
    end;

    // ---------- 3. Registration steps: To Bin Code, New Package No. ---------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnGetRegistrationConfiguration_OnAddSteps', '', true, true)]
    local procedure OnAddSteps_DecantItemReg(_RegistrationType: Text; var _HeaderFieldValues: Record "MOB NS Request Element"; var _Steps: Record "MOB Steps Element"; var _RegistrationTypeTracking: Text)
    var
        DecantDetails: Record "Decant Details";
        Template: Code[10];
        Batch: Code[10];
        LineNo: Integer;
        DefaultToBin: Code[20];
        DefaultNewPackage: Code[50];
    begin
        if not (_RegistrationType in ['DecantItemReg', 'DecantScreenLookup']) then
            exit;

        // Pre-fill the two scan steps with the current values on the matching
        // Decant Details row so the operator can just confirm or overwrite.
        Template := CopyStr(_HeaderFieldValues.GetValue('Template'), 1, MaxStrLen(Template));
        Batch := CopyStr(_HeaderFieldValues.GetValue('Batch'), 1, MaxStrLen(Batch));
        LineNo := _HeaderFieldValues.GetValueAsInteger('LineNumber');

        if (Template <> '') and (Batch <> '') and (LineNo > 0) then begin
            DecantDetails.SetRange("Journal Template Name", Template);
            DecantDetails.SetRange("Journal Batch Name", Batch);
            DecantDetails.SetRange("Line No.", LineNo);
            if DecantDetails.FindFirst() then begin
                DefaultToBin := DecantDetails."To Bin Code";
                DefaultNewPackage := DecantDetails."New Package No.";
            end;
        end;

        _Steps.Create_TextStep(1, 'ToBinCode', 'Scan To Bin Code');
        if DefaultToBin <> '' then
            _Steps.Set_DefaultValue(DefaultToBin);

        _Steps.Create_TextStep(2, 'NewPackageNo', 'Scan New Package No.');
        if DefaultNewPackage <> '' then
            _Steps.Set_DefaultValue(DefaultNewPackage);
    end;

    // ---------- 4. Post: save scans + run Item Reclass for this single line --

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Adhoc Registr.", 'OnPostAdhocRegistrationOnCustomRegistrationType', '', true, true)]
    local procedure OnPostAdhocRegistration_DecantItemReg(_MessageId: Guid; _RegistrationType: Text; var _RequestValues: Record "MOB NS Request Element"; var _CurrentRegistrations: Record "MOB WMS Registration"; var _SuccessMessage: Text; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        TemplateName: Code[10];
        BatchName: Code[10];
        LineNo: Integer;
        ToBinCode: Code[20];
        NewPackageNo: Code[50];
    begin
        if _IsHandled then
            exit;
        if _RegistrationType <> 'DecantItemReg' then
            exit;

        TemplateName := CopyStr(_RequestValues.GetValue('Template'), 1, MaxStrLen(TemplateName));
        BatchName := CopyStr(_RequestValues.GetValue('Batch'), 1, MaxStrLen(BatchName));
        LineNo := _RequestValues.GetValueAsInteger('LineNumber');
        ToBinCode := CopyStr(_RequestValues.GetValue('ToBinCode'), 1, MaxStrLen(ToBinCode));
        NewPackageNo := CopyStr(_RequestValues.GetValue('NewPackageNo'), 1, MaxStrLen(NewPackageNo));

        DecantPostMgt.PostSingleDecantLine(TemplateName, BatchName, LineNo, ToBinCode, NewPackageNo);

        _SuccessMessage := PostedOkMsgTok;
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
        exit('From: ' + DecantDetails."From Bin Code" + '  ->  To: ' + DecantDetails."To Bin Code");
    end;

    local procedure BuildPackageLine(DecantDetails: Record "Decant Details"): Text
    begin
        if DecantDetails."Package No." = '' then
            exit('');
        exit('Pkg: ' + DecantDetails."Package No.");
    end;

}
