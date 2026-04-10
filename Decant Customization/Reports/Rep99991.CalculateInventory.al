report 99991 CalculateInventory
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    CaptionML = ENU = 'Calculate Inventory';
    ProcessingOnly = true;
    dataset
    {
        dataitem(CopyLoop; "Integer")
        {
            DataItemTableView = SORTING(Number);
            dataitem(PageLoop; "Integer")
            {
                DataItemTableView = SORTING(Number) WHERE(Number = CONST(1));

            }
            trigger OnAfterGetRecord();
            begin

                if Number > 1 then begin
                    CopyText := FormatDocument.GetCOPYText;
                    OutputNo += 1;
                end;

                FillTempTable();

                //Message(Format(OutputNo));
                //Message(GloTemplateName);
                //Message(GloBatchName);
                //Message(GloLocationName);
            end;

            trigger OnPreDataItem();
            begin
                //NoOfLoops := ABS(NoOfCopies);
                NoOfLoops := 1;
                CopyText := '';
                SETRANGE(Number, 1, NoOfLoops);
                OutputNo := 1;
            end;
        }
    }
    requestpage
    {
        layout
        {
            area(Content)
            {
                group(GroupName)
                {
                }
            }
        }
        actions
        {
            area(Processing)
            {
            }
        }
    }
    var
        NoOfCopies: Integer;
        NoOfLoops: Integer;
        CopyText: Text[30];
        OutputNo: Integer;
        FormatDocument: Codeunit "Format Document";
        GloTemplateName: Code[10];
        GloBatchName: Code[10];
        GloLocationName: Code[10];
        ItemFilter: Code[50];
        ItemFilter2: Code[50];
        LotFilter: Code[50];

        BinCodeFilter: Code[20];
        ZoneCodeFilter: Code[10];
        StatusFilter: Code[10];
        NewStatus: Code[10];
        GloItemDescription: Text[250];

    procedure GetFilter(TemplateName: Code[10]; BatchName: Code[10]; LocationName: Code[10]; ItemNo: Code[50]; ItemDescription: text[250])
    var
    begin
        Clear(GloTemplateName);
        Clear(GloBatchName);
        Clear(GloLocationName);
        Clear(ItemFilter2);
        Clear(GloItemDescription);

        GloTemplateName := TemplateName;
        GloBatchName := BatchName;
        GloLocationName := LocationName;
        ItemFilter2 := ItemNo;
        GloItemDescription := ItemDescription;
    end;

    local procedure FillTempTable()
    var
        LotNosByBinCode: Query "LotNo. WHSE Entry MovementWrk";
        ItemTrackingManagement: Codeunit 6500;
        EntriesExist: Boolean;
        L_RecDecantDetails: Record "Decant Details";
        Line: Integer;
        FilterFound: Boolean;
        L_DecanDetails: Record "Decant Details";
        L_DecanDetails2: Record "Decant Details";
        RecItem: Record Item;
        //RecStatusMaster: Record "Status Master";
        RecBinCode: Record Bin;
        ItemTrackingSetup: Record "Item Tracking Setup";
        RecBintype: Record "Bin Type";
        RecBin: Record Bin;
        BinTypeSkip: Boolean;
        PutFound: Boolean;
        PickFOund: Boolean;
    begin
        Clear(Line);
        L_DecanDetails2.Reset();
        L_DecanDetails2.SetRange("Journal Template Name", GloTemplateName);
        L_DecanDetails2.SetRange("Journal Batch Name", GloBatchName);
        if L_DecanDetails2.FindSet() then begin
            L_DecanDetails2.DELETEALL;
        end;
        Commit();

        //LotNosByBinCode.SETRANGE(Item_No, Rec.GETRANGEMIN("Item No."));//og
        /*
        if ItemFilter <> '' then
            LotNosByBinCode.SetFilter(Item_No, ItemFilter);*/
        if ItemFilter2 <> '' then
            LotNosByBinCode.SetFilter(Item_No, ItemFilter2);
        //LotNosByBinCode.SETRANGE(Item_No, ItemFilter);
        if GloLocationName <> '' then
            LotNosByBinCode.SetFilter(LotNosByBinCode.Location_Code, GloLocationName);
        if LotFilter <> '' then
            LotNosByBinCode.SetFilter(LotNosByBinCode.Lot_No, LotFilter);
        //LotNosByBinCode.SetRange(LotNosByBinCode.Lot_No, LotFilter);
        if ZoneCodeFilter <> '' then
            LotNosByBinCode.SetFilter(LotNosByBinCode.Zone_Code, ZoneCodeFilter);

        if BinCodeFilter <> '' then
            LotNosByBinCode.SetFilter(LotNosByBinCode.Bin_Code, BinCodeFilter);
        if StatusFilter <> '' then
            LotNosByBinCode.SetFilter(LotNosByBinCode.Status, StatusFilter);
        // Manish ++
        //IF UserSetup.GET(USERID) THEN BEGIN
        //  IF ResponsibilityCenter.GET(UserSetup."Sales Resp. Ctr. Filter") THEN BEGIN
        //SETFILTER("Location Filter",ResponsibilityCenter."Location Code");
        //CALCFIELDS(Inventory);
        //  END
        //END;
        // Manish --
        Line := 10000;
        if L_RecDecantDetails.FindLast() then begin

        end;

        LotNosByBinCode.OPEN;

        WHILE LotNosByBinCode.READ DO BEGIN
            L_DecanDetails.INIT;
            L_DecanDetails."Journal Template Name" := GloTemplateName;
            L_DecanDetails."Journal Batch Name" := GloBatchName;
            L_DecanDetails."Line No." := L_RecDecantDetails."Line No." + Line;
            L_DecanDetails."Item No." := LotNosByBinCode.Item_No;
            L_DecanDetails."Unit of Measure Code" := LotNosByBinCode.Unit_of_Measure_Code;//Azhar++ 28 March 2022
            L_DecanDetails."Variant Code" := LotNosByBinCode.Variant_Code;
            L_DecanDetails."Location Code" := LotNosByBinCode.Location_Code;
            L_DecanDetails."From Zone Code" := LotNosByBinCode.Zone_Code;
            L_DecanDetails."From Bin Code" := LotNosByBinCode.Bin_Code;
            L_DecanDetails."Lot No." := LotNosByBinCode.Lot_No;
            //  Rec."Manufacturer Code" := LotNosByBinCode.Manufacturer_Code;//LotBreakup
            ItemTrackingSetup."Lot No." := LotNosByBinCode.Lot_No;
            L_DecanDetails."Expiry Date" := ItemTrackingManagement.ExistingExpirationDate(LotNosByBinCode.Item_No, LotNosByBinCode.Variant_Code, ItemTrackingSetup, FALSE, EntriesExist);
            L_DecanDetails.Quantity := LotNosByBinCode.Sum_Quantity;
            RecItem.Reset();
            RecItem.SetRange("No.", L_DecanDetails."Item No.");
            if RecItem.FindFirst() then begin
                L_DecanDetails.Description := RecItem.Description;
            end;
            //L_DecanDetails.Description := LotNosByBinCode.Item_Description;
            //L_DecanDetails.Status := LotNosByBinCode.Status;

            // RecLotByBin."New Status" := NewStatus;
            // RecLotByBin."To Qty." := RecLotByBin.Quantity;
            // RecStatusMaster.Reset();
            // RecStatusMaster.SetRange("Status Code", NewStatus);
            // if RecStatusMaster.FindFirst() then begin
            //     if RecStatusMaster."Default Bin" <> '' then begin
            //         RecLotByBin."To Bin Code" := RecStatusMaster."Default Bin";
            //         RecBinCode.Reset();
            //         RecBinCode.SetRange(Code, RecLotByBin."To Bin Code");
            //         if RecBinCode.FindFirst() then begin
            //             RecLotByBin."To Zone Code" := RecBinCode."Zone Code";
            //         end;
            //     end else begin
            //         RecLotByBin."To Bin Code" := RecLotByBin."From Bin Code";
            //         RecLotByBin."To Zone Code" := RecLotByBin."From Zone Code";
            //     end;
            // end;

            //March 15 2022++
            Clear(BinTypeSkip);
            Clear(PutFound);
            Clear(PickFOund);
            if L_DecanDetails."From Bin Code" <> '' then begin
                RecBin.Reset();
                RecBin.SetRange(Code, L_DecanDetails."From Bin Code");
                if RecBin.FindFirst() then begin
                    RecBintype.Reset();
                    RecBintype.SetRange(Code, RecBin."Bin Type Code");
                    if RecBintype.FindFirst() then begin
                        if RecBintype."Put Away" = true then
                            PutFound := true;
                        if RecBintype.Pick = true then begin
                            PickFOund := true;
                        end;
                    end;

                    if (PutFound = false) and (PickFOund = false) then
                        BinTypeSkip := true;

                    if BinTypeSkip = false then begin

                        //March 15 2022--

                        IF L_DecanDetails.Quantity <> 0 THEN begin
                            L_DecanDetails.INSERT;
                            Line += 10000;
                        end;
                    END;//March 15 2022++
                end;//March 15 2022--
            end;//March 15 2022--
        end;
    end;
}
