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
            field(DestLocationCodeField; DestLocationCode)
            {
                ApplicationArea = All;
                Caption = 'Dest. Location Code';
                TableRelation = Location.Code;
                ToolTip = 'Specifies the destination location for GEN DECANT movement.';
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
                field("To Location Code"; Rec."To Location Code")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Manufacturer Code"; Rec."Manufacturer Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Select the Manufacturer to determine Qty Per Tote.';
                }
                field("Qty Per Tote"; Rec."Qty Per Tote")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Number of Totes"; Rec."Number of Totes")
                {
                    ApplicationArea = All;
                    Editable = false;
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
            // action("Calculate inventory")
            // {
            //     ApplicationArea = All;
            //     Caption = 'Calculate inventory';
            //     Image = GetBinContent;
            //     Promoted = true;
            //     PromotedCategory = Process;
            //     PromotedIsBig = true;
            //     trigger OnAction()
            //     var
            //         RepCalcInven: Report CalculateInventory;
            //     begin
            //         Clear(RepCalcInven);
            //         //Message(CurrentJnlBatchName);
            //         //Message(CurrentLocationCode);
            //         //Message("Journal Template Name");
            //         RepCalcInven.GetFilter(Rec."Journal Template Name", CurrentJnlBatchName, CurrentLocationCode, ItemFilter, ItemDescription);
            //         RepCalcInven.Run();
            //         CurrPage.Update();
            //         //FillTempTable();
            //     end;
            // }
            action("Calculate GEN DECANT")
            {
                ApplicationArea = All;
                Caption = 'Calculate GEN DECANT';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Calculates items to move from source GEN DECANT zone to destination GEN DECANT zone based on empty totes.';

                trigger OnAction()
                var
                    GenDecantCU: Codeunit CreateDecantWhseReclassAndPost;
                begin
                    if DestLocationCode = '' then
                        Error('Please specify the Dest. Location Code.');

                    GenDecantCU.CalculateGenDecant(
                        Rec."Journal Template Name",
                        CurrentJnlBatchName,
                        CurrentLocationCode,
                        DestLocationCode,
                        ItemFilter
                    );
                    CurrPage.Update(false);
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
                    GenDecantCU: Codeunit CreateDecantWhseReclassAndPost;
                begin
                    GenDecantCU.RegisterGenDecant(
                        Rec."Journal Template Name",
                        CurrentJnlBatchName
                    );
                    CurrPage.Update(false);
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
        Rec.OpenJnl(CurrentJnlBatchName, CurrentLocationCode, DestLocationCode, Rec);
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
        DestLocationCode: Code[10];
}
