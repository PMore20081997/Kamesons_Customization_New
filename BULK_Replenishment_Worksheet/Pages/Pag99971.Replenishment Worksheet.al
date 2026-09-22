page 99971 "Bulk Replan"
{
    ApplicationArea = Basic, Suite;
    Caption = 'Bulk Replan';
    DataCaptionFields = "Journal Batch Name";
    DelayedInsert = true;
    PageType = Worksheet;
    SaveValues = true;
    SourceTable = "Decant Details";
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            field("Journal Batch Name"; Rec."Journal Batch Name")
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
                    Rec.LookupName(CurrentJnlBatchName, CurrentLocationCode, Rec);
                    CurrPage.Update(false);
                end;

                trigger OnValidate()
                begin
                    Rec.CheckName(CurrentJnlBatchName, CurrentLocationCode, Rec);
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
                    L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
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
                        // BULK = the item holds Bin Content in a BULK-flagged
                        // bin in MAIN. An item that also has a Static or
                        // Flowrack face still qualifies for BULK replenishment.
                        if not L_KamWhseSetupLookup.ItemHasRoutingType(L_Item."No.", "Item Routing Type NDPP"::BULK) then begin
                            ItemFilter := '';
                            ItemDescription := '';
                            ApplyItemFilter();
                            CurrPage.Update();
                            Error('Item %1 has no BULK bin in the main warehouse. Only items with a BULK bin are allowed.', L_Item."No.");
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
                    L_ItemFilter: Text;
                begin
                    // Items with a BULK bin in MAIN. Routing types live in Bin
                    // Content, so the list is built from the BULK bins' contents
                    // rather than filtered on the item table.
                    L_ItemFilter := GetBulkItemNoFilter();
                    if L_ItemFilter = '' then
                        Error('No items are assigned to a BULK bin in the main warehouse.');

                    L_Item.Reset();
                    L_Item.SetFilter("No.", L_ItemFilter);
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
                field(Status; Rec.Status)
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
                // "To Location Code" = destination (main warehouse)
                field("Available Qty. to Take"; Rec."Available Qty. to Take")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    Caption = 'Available Quantity';
                    Editable = false;
                    ToolTip = 'Available to take from bin content';
                }
                // "Location Code" = source/from location (receive location)
                field("From Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'From Location Code';
                }
                field("From Bin Code"; Rec."From Bin Code")
                {
                    ToolTip = 'Specifies the value of the From Bin Code field.', Comment = '%';
                    ApplicationArea = All;
                }
                field("To Location Code"; Rec."To Location Code")
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    Editable = false;
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the value of the Lot No. field.', Comment = '%';
                    ApplicationArea = All;
                }
                field("Expiry Date"; Rec."Expiry Date")
                {
                    ToolTip = 'Specifies the expiration date.', Comment = '%';
                    Caption = 'Expiration Date';
                    ApplicationArea = All;
                }
                field("To Bin Code"; Rec."To Bin Code")
                {
                    ToolTip = 'Specifies the value of the To Bin Code field.', Comment = '%';
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
                field("Manufacturer Name"; Rec."Manufacturer Name")
                {
                    ApplicationArea = All;
                    Caption = 'Manufacturer Name';
                    Editable = false;
                    ToolTip = 'Specifies the name of the manufacturer for the Manufacturer Code.';
                }
                field("Qty to Move"; Rec."To Qty.")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0 : 5;
                    Caption = 'Qty to Move';
                    ToolTip = 'System suggestion Qty to Move';
                }
            }
        }
        area(Factboxes)
        {
            part(ReceiveBinContentDetails; "Bin Content Details")
            {
                // "Location Code" in Decant Details = source (receive) location
                SubPageLink = "Item No." = field("Item No."), "Location Code" = field("Location Code");
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
                    ReplenishBinContent: Report "Cal _Bin Replenishment New";
                    L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
                    L_Item: Record Item;
                    L_DecantDetails: Record "Decant Details";
                begin
                    // Clear the batch's unprocessed Replenishment lines so repeated presses
                    // recalculate rather than stack duplicates (matches the Job Queue path).
                    L_DecantDetails.Reset();
                    L_DecantDetails.SetRange("Entry Type", L_DecantDetails."Entry Type"::Replenishment);
                    L_DecantDetails.SetRange("Journal Template Name", Rec."Journal Template Name");
                    L_DecantDetails.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                    if not L_DecantDetails.IsEmpty() then
                        L_DecantDetails.DeleteAll();

                    Commit();
                    ReplenishBinContent.InitializeRequest(Rec."Journal Template Name", Rec."Journal Batch Name", L_KamWhseSetupLookup.GetMainLocation(), false);
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
                    L_DecantDetails: Record "Decant Details";
                    L_ReqLine: Record "Requisition Line";
                    L_BatchName: Code[10];
                    L_LineNo: Integer;
                    ProcessCompletedMsg: Label 'Process completed.';
                    NothingToRegisterMsg: Label 'No lines with Action = Accept and Qty to Move > 0 were selected.';
                begin
                    L_BatchName := Rec."Journal Batch Name";

                    L_DecantDetails.Reset();
                    L_DecantDetails.SetRange("Entry Type", L_DecantDetails."Entry Type"::Replenishment);
                    L_DecantDetails.SetRange("Status", L_DecantDetails."Status"::Accept);
                    L_DecantDetails.SetRange("Journal Batch Name", L_BatchName);
                    L_DecantDetails.SetFilter("To Qty.", '>%1', 0);
                    if not L_DecantDetails.FindSet() then begin
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
                        G_Replenishment_Worksheet.CreateReqWorksheet(L_DecantDetails, L_LineNo);
                    until L_DecantDetails.Next() = 0;

                    L_DecantDetails.DeleteAll();

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
        G_Replenishment_Worksheet: Codeunit "Replenishment Worksheet";


    trigger OnOpenPage()
    var
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        JnlSelected: Boolean;
    begin
        Rec.FilterGroup := 2;
        Rec.SetRange("Entry Type", Rec."Entry Type"::Replenishment);
        Rec.FilterGroup := 0;

        if Rec.IsOpenedFromBatch() then begin
            CurrentJnlBatchName := Rec."Journal Batch Name";
            Rec.OpenJnl(CurrentJnlBatchName, CurrentLocationCode, DestLocationCode, Rec);
            CurrentLocationCode := L_KamWhseSetupLookup.GetReceiveLocation();
            DestLocationCode := L_KamWhseSetupLookup.GetMainLocation();
            exit;
        end;

        Rec.TemplateSelection(PAGE::"Bulk Replan", 2, Rec, JnlSelected);
        if not JnlSelected then
            Error('');
        Rec.OpenJnl(CurrentJnlBatchName, CurrentLocationCode, DestLocationCode, Rec);
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

    /// <summary>
    /// A '|'-separated filter of every item holding Bin Content in a
    /// BULK-flagged bin in MAIN — the items this worksheet replenishes.
    ///
    /// Built by walking the BULK bins rather than filtering the item table:
    /// routing types are derived from Bin Content, so there is no field on Item
    /// to filter on. Returns '' when no BULK bin holds any item.
    /// </summary>
    local procedure GetBulkItemNoFilter(): Text
    var
        L_Bin: Record Bin;
        L_BinContent: Record "Bin Content";
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        L_ItemNos: List of [Code[20]];
        L_ItemNo: Code[20];
        L_MainLocation: Code[20];
        L_Filter: TextBuilder;
    begin
        L_MainLocation := L_KamWhseSetupLookup.GetMainLocation();

        L_Bin.SetRange("Location Code", L_MainLocation);
        L_Bin.SetRange(Bulk, true);
        if L_Bin.FindSet() then
            repeat
                L_BinContent.Reset();
                L_BinContent.SetRange("Location Code", L_MainLocation);
                L_BinContent.SetRange("Bin Code", L_Bin.Code);
                L_BinContent.SetLoadFields("Item No.");
                if L_BinContent.FindSet() then
                    repeat
                        if not L_ItemNos.Contains(L_BinContent."Item No.") then
                            L_ItemNos.Add(L_BinContent."Item No.");
                    until L_BinContent.Next() = 0;
            until L_Bin.Next() = 0;

        foreach L_ItemNo in L_ItemNos do begin
            if L_Filter.Length() > 0 then
                L_Filter.Append('|');
            L_Filter.Append(L_ItemNo);
        end;

        exit(L_Filter.ToText());
    end;

    local procedure CurrentJnlBatchNameOnAfterValidate()
    begin
        CurrPage.SaveRecord();
        Rec.SetName(CurrentJnlBatchName, CurrentLocationCode, Rec);
        CurrPage.Update(false);
    end;
}
