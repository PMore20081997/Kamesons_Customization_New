page 99971 "Replenishment Worksheet"
{
    ApplicationArea = Basic, Suite;
    AutoSplitKey = true;
    Caption = 'Replenishment Worksheet';
    DataCaptionFields = "Batch Name";
    DelayedInsert = true;
    PageType = Worksheet;
    SaveValues = true;
    SourceTable = "Replenishment Worksheet";
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            field("Batch Name"; Rec."Batch Name")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Batch Name field.', Comment = '%';
                Visible = false;
            }
            field(CurrentJnlBatchName; CurrentJnlBatchName)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Batch Name';
                Lookup = true;

                trigger OnLookup(var Text: Text): Boolean
                begin
                    CurrPage.SaveRecord();
                    LookupName(CurrentJnlBatchName, Rec);
                    CurrPage.Update(false);
                end;

                trigger OnValidate()
                begin
                    CheckName(CurrentJnlBatchName, Rec);
                    CurrentJnlBatchNameOnAfterValidate();
                end;
            }
            field(CurrentLocationCode; CurrentLocationCode)
            {
                ApplicationArea = Location;
                Caption = 'Location Code';
                Editable = false;
                Lookup = true;
                TableRelation = Location;
                ToolTip = 'Specifies the source location for the replenishment (Receive location).';
            }
            field(G_ItemBarcode; G_ItemBarcode)
            {
                ApplicationArea = All;
                Caption = 'Item Barcode';

                trigger OnValidate()
                var
                    L_ItemRef: Record "Item Reference";
                    L_Item: Record Item;
                begin
                    if G_ItemBarcode = '' then begin
                        ItemFilter := '';
                        ItemDescription := '';
                        ApplyItemFilter();
                        CurrPage.Update();
                        exit;
                    end;

                    L_ItemRef.Reset();
                    L_ItemRef.SetRange("Reference Type", L_ItemRef."Reference Type"::"Bar Code");
                    L_ItemRef.SetRange("Reference No.", G_ItemBarcode);
                    if not L_ItemRef.FindFirst() then begin
                        ItemFilter := '';
                        ItemDescription := '';
                        ApplyItemFilter();
                        CurrPage.Update();
                        Error('No item found with barcode %1.', G_ItemBarcode);
                    end;

                    ItemFilter := L_ItemRef."Item No.";
                    if L_Item.Get(ItemFilter) then begin
                        if L_Item."Routing Type" <> "Item Routing Type NDPP"::BULK then begin
                            ItemFilter := '';
                            ItemDescription := '';
                            ApplyItemFilter();
                            CurrPage.Update();
                            Error('Item %1 has Routing Type %2. Only BULK items are allowed.', L_Item."No.", L_Item."Routing Type");
                        end;
                        ItemDescription := L_Item.Description;
                    end else
                        ItemDescription := '';

                    ApplyItemFilter();
                    CurrPage.Update();
                end;
            }
            field(ItemFilter; ItemFilter)
            {
                ApplicationArea = All;
                Caption = 'Item No.';
                TableRelation = Item."No.";

                trigger OnLookup(var Text: Text): Boolean
                var
                    L_Item: Record Item;
                    L_ItemList: Page "Item List";
                begin
                    L_Item.Reset();
                    L_Item.SetFilter("Routing Type", '%1', "Item Routing Type NDPP"::BULK);
                    L_ItemList.SetTableView(L_Item);
                    L_ItemList.LookupMode(true);
                    if L_ItemList.RunModal() = Action::LookupOK then begin
                        L_ItemList.GetRecord(L_Item);
                        ItemFilter := L_Item."No.";
                        ItemDescription := L_Item.Description;
                        Text := ItemFilter;
                        ApplyItemFilter();
                        CurrPage.Update();
                        exit(true);
                    end;
                end;

                trigger OnValidate()
                var
                    RecItem: Record Item;
                begin
                    if ItemFilter <> '' then begin
                        RecItem.Reset();
                        RecItem.SetRange("No.", ItemFilter);
                        if RecItem.FindFirst() then
                            ItemDescription := RecItem.Description
                        else
                            ItemDescription := '';
                    end else
                        ItemDescription := '';
                    ApplyItemFilter();
                    CurrPage.Update();
                end;
            }
            field("Item Description"; ItemDescription)
            {
                ApplicationArea = All;
                Caption = 'Item Description';
                Editable = false;
            }
            field(DestLocationCodeField; DestLocationCode)
            {
                ApplicationArea = All;
                Caption = 'Dest. Location Code';
                Editable = false;
                TableRelation = Location.Code;
                ToolTip = 'Specifies the destination location (MAIN Warehouse).';
            }
            repeater(GroupName)
            {
                field(Action; Rec.Action)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the action to be performed on the line. Only Accept action lines can be registered.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the item number for which replenishment is planned.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the description of the item.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("System Quantity"; Rec."System Quantity")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    Caption = 'Available Quantity';
                    Editable = false;
                    ToolTip = 'Available to take from bincontent';
                }

                field("From Location Code"; Rec."From Location Code")
                {
                    ApplicationArea = All;
                }
                field("From Bin Code"; Rec."From Bin Code")
                {
                    ToolTip = 'Specifies the value of the From Bin Code field.', Comment = '%';
                    ApplicationArea = All;
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                    ApplicationArea = All;
                }
                field("Expiration Date"; Rec."Expiration Date")
                {
                    ToolTip = 'Specifies the value of the Expiration Date field.', Comment = '%';
                    ApplicationArea = All;
                }
                field("Package No."; Rec."Package No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Package No. field.', Comment = '%';
                }
                field("Manufacturer Code"; Rec."Manufacturer Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Manufacturer Code field.', Comment = '%';
                }
                field("Qty to Move"; Rec."Qty to Move")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    ToolTip = 'System suggestion Qty to Move';
                }
            }
        }
        area(Factboxes)
        {
            part(ReceiveBinContentDetails; "Bin Content Details")
            {
                SubPageLink = "Item No." = field("Item No."), "Location Code" = field("From Location Code");

                ApplicationArea = all;
                Caption = 'Receive Bin Content Details';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action("Calculate Bin Replenishment")
            {
                ApplicationArea = all;
                Caption = 'Calculate Bin Replenishment';
                Ellipsis = true;
                Image = CalculateBinReplenishment;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    Location: Record Location;
                    ReplenishBinContent: Report "Cal _Bin Replenishment New";
                    L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
                    L_Item: Record Item;
                begin
                    Commit();
                    Location.Get(L_KamWhseSetupLookup.GetMainLocation());
                    ReplenishBinContent.InitializeRequest(Rec."Template Name", Rec."Batch Name", L_KamWhseSetupLookup.GetMainLocation(), false);
                    if ItemFilter <> '' then begin
                        L_Item.SetFilter("No.", ItemFilter);
                        ReplenishBinContent.SetTableView(L_Item);
                    end;
                    ReplenishBinContent.Run();
                    Clear(ReplenishBinContent);
                    CurrPage.Update(false);
                end;
            }
            action(Register)
            {
                ApplicationArea = all;
                Caption = '&Register';
                Image = Register;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Registers the selected Accept lines: creates the corresponding requisition lines and processes them into transfer documents.';

                trigger OnAction()
                var
                    L_ReplenishmentWorksheet: Record "Replenishment Worksheet";
                    L_ReqLine: Record "Requisition Line";
                    L_BatchName: Code[10];
                    L_LineNo: Integer;
                    ProcessCompletedMsg: Label 'Process completed.';
                    NothingToRegisterMsg: Label 'No lines with Action = Accept and Qty to Move > 0 were selected.';
                begin
                    L_BatchName := Rec."Batch Name";

                    L_ReplenishmentWorksheet.Reset();
                    L_ReplenishmentWorksheet.SetRange(Action, L_ReplenishmentWorksheet.Action::Accept);
                    L_ReplenishmentWorksheet.SetRange("Batch Name", L_BatchName);
                    L_ReplenishmentWorksheet.SetFilter("Qty to Move", '>%1', 0);
                    if not L_ReplenishmentWorksheet.FindSet() then begin
                        Message(NothingToRegisterMsg);
                        exit;
                    end;

                    // Clear any previously-created replenishment requisition lines for this batch
                    L_ReqLine.Reset();
                    L_ReqLine.SetRange("Journal Batch Name", L_BatchName);
                    L_ReqLine.SetRange("Created By Repl.", true);
                    if not L_ReqLine.IsEmpty() then
                        L_ReqLine.DeleteAll();

                    repeat
                        L_LineNo := L_LineNo + 10000;
                        G_Replenishment_Worksheet.CreateReqWorksheet(L_ReplenishmentWorksheet, L_LineNo);
                    until L_ReplenishmentWorksheet.Next() = 0;

                    L_ReplenishmentWorksheet.DeleteAll();

                    L_ReqLine.Reset();
                    L_ReqLine.SetRange("Journal Batch Name", L_BatchName);
                    L_ReqLine.SetRange("Created By Repl.", true);
                    if L_ReqLine.FindSet() then
                        G_Replenishment_Worksheet.ProcessReqLineActions(L_ReqLine);

                    Message(ProcessCompletedMsg);
                end;
            }

        }
    }
    var
        CurrentJnlBatchName: Code[10];
        CurrentLocationCode: Code[10];
        DestLocationCode: Code[10];
        ItemFilter: Code[50];
        ItemDescription: Text[250];
        G_ItemBarcode: Code[250];
        Text000: Label '%1 journal';
        Text001: Label 'RECURRING';
        Text002: Label 'Recurring Item Journal';
        Text005: Label 'REC-';
        Text006: Label 'Recurring ';
        OpenFromBatch: Boolean;
        G_Replenishment_Worksheet: Codeunit "Replenishment Worksheet";


    trigger OnOpenPage()
    var
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        JnlSelected: Boolean;
    begin
        if Rec.IsOpenedFromBatch() then begin
            CurrentJnlBatchName := Rec."Batch Name";
            Rec.OpenJnl(CurrentJnlBatchName, Rec);
            CurrentLocationCode := L_KamWhseSetupLookup.GetReceiveLocation();
            DestLocationCode := L_KamWhseSetupLookup.GetMainLocation();
            exit;
        end;


        TemplateSelection(PAGE::"Item Reclass. Journal", 1, false, Rec, JnlSelected);
        if not JnlSelected then
            Error('');
        Rec.OpenJnl(CurrentJnlBatchName, Rec);
        CurrentLocationCode := L_KamWhseSetupLookup.GetReceiveLocation();
        DestLocationCode := L_KamWhseSetupLookup.GetMainLocation();
    end;

    local procedure ApplyItemFilter()
    begin
        Rec.FilterGroup := 0;
        if ItemFilter <> '' then
            Rec.SetFilter("Item No.", ItemFilter)
        else
            Rec.SetRange("Item No.");
    end;


    local procedure CurrentJnlBatchNameOnAfterValidate()
    begin
        CurrPage.SaveRecord();
        SetName(CurrentJnlBatchName, Rec);
        CurrPage.Update(false);
    end;

    procedure SetName(CurrentJnlBatchName: Code[10]; var _ReplanishmentWorksheet: Record "Replenishment Worksheet")
    begin
        _ReplanishmentWorksheet.FilterGroup := 2;
        _ReplanishmentWorksheet.SetRange("Batch Name", CurrentJnlBatchName);
        _ReplanishmentWorksheet.FilterGroup := 0;
        if _ReplanishmentWorksheet.Find('-') then;
    end;

    procedure LookupName(var CurrentJnlBatchName: Code[10]; var _ReplanishmentWorksheet: Record "Replenishment Worksheet")
    var
        //ItemJnlBatch: Record "Item Journal Batch";
        L_ReqWorkshtTemNm: Record "Requisition Wksh. Name";
        IsHandled: Boolean;
    begin
        Commit();
        L_ReqWorkshtTemNm."Worksheet Template Name" := _ReplanishmentWorksheet.GetRangeMax("Template Name");
        L_ReqWorkshtTemNm.Name := _ReplanishmentWorksheet.GetRangeMax("Batch Name");
        L_ReqWorkshtTemNm.FilterGroup(2);
        L_ReqWorkshtTemNm.SetRange("Worksheet Template Name", L_ReqWorkshtTemNm."Worksheet Template Name");
        L_ReqWorkshtTemNm.FilterGroup(0);
        IsHandled := false;
        if not IsHandled then
            if PAGE.RunModal(0, L_ReqWorkshtTemNm) = ACTION::LookupOK then begin
                CurrentJnlBatchName := L_ReqWorkshtTemNm.Name;
                SetName(CurrentJnlBatchName, _ReplanishmentWorksheet);
            end;
    end;

    procedure CheckName(CurrentJnlBatchName: Code[10]; var _ReplanishmentWorksheet: Record "Replenishment Worksheet")
    var
        L_ReqWorkshtTemNm: Record "Requisition Wksh. Name";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        if IsHandled then
            exit;

        L_ReqWorkshtTemNm.Get(_ReplanishmentWorksheet.GetRangeMax("Template Name"), CurrentJnlBatchName);
    end;

    procedure TemplateSelection(PageID: Integer; PageTemplate: Option Item,Transfer,"Phys. Inventory",Revaluation,Consumption,Output,Capacity,"Prod. Order"; RecurringJnl: Boolean; var _ReplanishmentWorksheet: Record "Replenishment Worksheet"; var JnlSelected: Boolean)
    var
        ItemJnlTemplate: Record "Item Journal Template";
    begin
        JnlSelected := true;

        ItemJnlTemplate.Reset();
        ItemJnlTemplate.SetRange("Page ID", PageID);
        ItemJnlTemplate.SetRange(Recurring, RecurringJnl);
        ItemJnlTemplate.SetRange(Type, PageTemplate);
        case ItemJnlTemplate.Count of
            0:
                begin
                    ItemJnlTemplate.Init();
                    ItemJnlTemplate.Recurring := RecurringJnl;
                    ItemJnlTemplate.Validate(Type, PageTemplate);
                    ItemJnlTemplate.Validate("Page ID");
                    if not RecurringJnl then begin
                        ItemJnlTemplate.Name := Format(ItemJnlTemplate.Type, MaxStrLen(ItemJnlTemplate.Name));
                        ItemJnlTemplate.Description := StrSubstNo(Text000, ItemJnlTemplate.Type);
                    end else
                        if ItemJnlTemplate.Type = ItemJnlTemplate.Type::Item then begin
                            ItemJnlTemplate.Name := Text001;
                            ItemJnlTemplate.Description := Text002;
                        end else begin
                            ItemJnlTemplate.Name :=
                              Text005 + Format(ItemJnlTemplate.Type, MaxStrLen(ItemJnlTemplate.Name) - StrLen(Text005));
                            ItemJnlTemplate.Description := Text006 + StrSubstNo(Text000, ItemJnlTemplate.Type);
                        end;
                    ItemJnlTemplate.Insert();
                    Commit();
                end;
            1:
                ItemJnlTemplate.FindFirst();
            else
                JnlSelected := PAGE.RunModal(0, ItemJnlTemplate) = ACTION::LookupOK;
        end;
        if JnlSelected then begin
            _ReplanishmentWorksheet.FilterGroup := 2;
            _ReplanishmentWorksheet.SetRange("Template Name", ItemJnlTemplate.Name);
            _ReplanishmentWorksheet.FilterGroup := 0;
            if OpenFromBatch then begin
                _ReplanishmentWorksheet."Template Name" := '';
                PAGE.Run(ItemJnlTemplate."Page ID", _ReplanishmentWorksheet);
            end;
        end;
    end;
}