page 99991 "Decant Screen"
{
    ApplicationArea = All;
    Caption = 'Decant Screen';
    PageType = Worksheet;
    DataCaptionFields = "Journal Batch Name";
    SourceTable = "Decant Details";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {

            field("Journal Batch Name"; Rec."Journal Batch Name")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Journal Batch Name field.', Comment = '%';
                Visible = false;
            }
            field("Location Filter"; LocationFilter)
            {
                ApplicationArea = All;
                TableRelation = Location.Code;
                Visible = false;
            }
            field(CurrentJnlBatchName; CurrentJnlBatchName)
            {
                ApplicationArea = All;
                Caption = 'Batch Name';
                Lookup = true;
                ToolTip = 'Specifies the name of the journal batch, a personalized journal layout, that the journal is based on.';

                trigger OnLookup(var Text: Text): Boolean
                begin
                    CurrPage.SaveRecord;
                    Rec.LookupName(CurrentJnlBatchName, CurrentLocationCode, Rec);
                    CurrPage.Update(false);
                end;

                trigger OnValidate()
                begin
                    Rec.CheckName(CurrentJnlBatchName, CurrentLocationCode, Rec);
                    CurrentJnlBatchNameOnAfterVali;
                end;
            }
            field(CurrentLocationCode; CurrentLocationCode)
            {
                ApplicationArea = Location;
                Caption = 'Location Code';
                Editable = false;
                Lookup = true;
                TableRelation = Location;
                ToolTip = 'Specifies the location where the warehouse activity takes place. ';
            }
            field(ItemFilter; ItemFilter)
            {
                ApplicationArea = All;
                TableRelation = Item."No.";
                Visible = true;
                Caption = 'Item No.';
                trigger OnValidate()
                var
                    RecItem: Record Item;
                begin
                    if ItemFilter <> '' then begin
                        RecItem.Reset();
                        RecItem.SetRange("No.", ItemFilter);
                        if RecItem.FindFirst() then begin
                            ItemDescription := RecItem.Description;
                            CurrPage.Update();
                        end else begin
                            ItemDescription := '';
                            CurrPage.Update();
                        end;
                    end else begin
                        ItemDescription := '';
                        CurrPage.Update();
                    end;
                end;
            }
            field("Item Description"; ItemDescription)
            {
                ApplicationArea = all;
                Editable = false;

            }

            repeater(General)
            {
                ShowCaption = false;
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                }

                field("Lot No."; Rec."Lot No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Expiry Date"; Rec."Expiry Date")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("From Zone Code"; Rec."From Zone Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("From Bin Code"; Rec."From Bin Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ApplicationArea = all;
                }
                field("Package No."; Rec."Package No.")
                {
                    ApplicationArea = all;
                    ToolTip = 'Specifies the value of the Package No. field.', Comment = '%';
                }

                field("To Zone Code"; Rec."To Zone Code")
                {
                    ApplicationArea = All;
                }

                field("To Bin Code"; Rec."To Bin Code")
                {
                    ApplicationArea = All;
                }
                field("To Qty."; Rec."To Qty.")
                {
                    ApplicationArea = All;
                }
                field("New Package No."; Rec."New Package No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Reason Code"; Rec."Reason Code")
                {
                    ApplicationArea = All;
                }

            }
        }
    }
    actions
    {
        area(Processing)
        {
            action("Calculate inventory")
            {
                ApplicationArea = All;
                Caption = 'Calculate inventory';
                Image = GetBinContent;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                trigger OnAction()
                var
                    RepCalcInven: Report CalculateInventory;
                begin
                    Clear(RepCalcInven);
                    //Message(CurrentJnlBatchName);
                    //Message(CurrentLocationCode);
                    //Message("Journal Template Name");
                    RepCalcInven.GetFilter(Rec."Journal Template Name", CurrentJnlBatchName, CurrentLocationCode, ItemFilter, ItemDescription);
                    RepCalcInven.Run();
                    CurrPage.Update();
                    //FillTempTable();
                end;
            }
            action(Register)
            {
                ApplicationArea = All;
                Caption = 'Register';
                Image = Register;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                trigger OnAction()
                var
                    // RecLotByBin: Record "Decant Details";
                    // CodeUnitTOcreateReclase: Codeunit "All Event";
                    // //RecStatusMaster: Record "Status Master";
                    // RecUser: Record "User Setup";
                    // PasswordRequired: Boolean;
                    // //RepEnterPasword: Report CheckPassword;
                begin
                    // //Abdul++
                    // if not Confirm('Do you want to register', false) then
                    //     exit;
                    // //Abdul--

                    // RecLotByBin.Reset();
                    // RecLotByBin.SetRange("Journal Template Name", Rec."Journal Template Name");
                    // RecLotByBin.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                    // RecLotByBin.SetFilter("To Qty.", '>%1', 0);
                    // if RecLotByBin.FindSet() then begin
                    //     repeat
                    //         if RecLotByBin."To Zone Code" = '' then
                    //             Error('Please Select To Zone Code Line No.:%1', RecLotByBin."Line No.");
                    //         if RecLotByBin."To Bin Code" = '' then
                    //             Error('Please Select To Bin Code Line No.:%1', RecLotByBin."Line No.");
                    //         if RecLotByBin."New Status" = '' then
                    //             Error('Please Select To Status Line No.:%1', RecLotByBin."Line No.");

                    //     until RecLotByBin.Next = 0;
                    // end;

                    // Clear(PasswordRequired);
                    // RecLotByBin.Reset();
                    // RecLotByBin.SetRange("Journal Template Name", Rec."Journal Template Name");
                    // RecLotByBin.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                    // RecLotByBin.SetFilter("To Qty.", '>%1', 0);
                    // if RecLotByBin.FindSet() then begin
                    //     repeat
                    //         RecStatusMaster.Reset();
                    //         //RecStatusMaster.SetRange("Status Code", RecLotByBin."New Status");
                    //         RecStatusMaster.SetRange("Status Code", RecLotByBin.Status);
                    //         if RecStatusMaster.FindFirst() then begin
                    //             if RecStatusMaster."Password Required" = true then begin
                    //                 PasswordRequired := true;
                    //             end;
                    //             if RecStatusMaster."Notes Required" = true then begin
                    //                 if RecLotByBin."Reason Code" = '' then begin
                    //                     //Error('Please Select Reason Code For Line : %1', RecLotByBin."Line No.");
                    //                     Error('Reason Code is Mandatory for Item No.:%1, Lot No.:%2, Bin Code:%3, Status:%4', RecLotByBin."Item No.", RecLotByBin."Lot No.", RecLotByBin."To Bin Code", RecLotByBin.Status);
                    //                 end;

                    //             end;
                    //         end;
                    //     until RecLotByBin.Next = 0;
                    // end;

                    // if PasswordRequired = true then begin
                    //     Clear(RepEnterPasword);
                    //     RepEnterPasword.getLotByBin(Rec);
                    //     RepEnterPasword.Run();
                    // end;

                    // if PasswordRequired = false then begin//CAS-28046-Q9W5H7

                    //     RecLotByBin.Reset();
                    //     RecLotByBin.SetRange("Journal Template Name", Rec."Journal Template Name");
                    //     RecLotByBin.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                    //     RecLotByBin.SetFilter("To Qty.", '>%1', 0);
                    //     if RecLotByBin.FindSet() then begin
                    //         repeat
                    //             CodeUnitTOcreateReclase.WarehouseReclassificationFromLotByBin(RecLotByBin);
                    //         until RecLotByBin.Next = 0;
                    //     end;

                    //     RecLotByBin.Reset();
                    //     RecLotByBin.SetRange("Journal Template Name", Rec."Journal Template Name");
                    //     RecLotByBin.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                    //     if RecLotByBin.FindSet() then begin
                    //         RecLotByBin.DeleteAll();
                    //     end;

                    // end;//CAS-28046-Q9W5H7
                end;
            }
        }
    }
    trigger OnOpenPage()
    var
        JnlSelected: Boolean;
        RecItem: Record Item;
    begin

        Rec.TemplateSelection(PAGE::"Whse. Reclassification Journal", 2, Rec, JnlSelected);

        if not JnlSelected then
            Error('');
        Rec.OpenJnl(CurrentJnlBatchName, CurrentLocationCode, Rec);
        if ItemFilter <> '' then begin
            RecItem.Reset();
            RecItem.SetRange("No.", ItemFilter);
            if RecItem.FindFirst() then begin
                ItemDescription := RecItem.Description;
                CurrPage.Update();
            end else begin
                ItemDescription := '';
                CurrPage.Update();
            end;
        end else begin
            ItemDescription := '';
            CurrPage.Update();
        end;
    end;


    local procedure CurrentJnlBatchNameOnAfterVali()
    begin
        CurrPage.SaveRecord;
        Rec.SetName(CurrentJnlBatchName, CurrentLocationCode, Rec);
        CurrPage.Update(false);
    end;





    var
        LocationFilter: Code[50];
        ItemFilter: Code[50];
        ItemDescription: text[250];
        CurrentJnlBatchName: Code[10];
        CurrentLocationCode: Code[10];
}
