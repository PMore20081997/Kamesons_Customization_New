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
                TableRelation = Item."No." where(BULK = const(false));
                Caption = 'Item No.';
                trigger OnValidate()
                var
                    RecItem: Record Item;

                    L_RecItemMan: Record "Item Manufacturer Table";
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

                        L_RecItemMan.Reset();
                        L_RecItemMan.SetRange("Item No", ItemFilter);
                        if L_RecItemMan.FindSet() and (L_RecItemMan.Count = 1) then begin
                            ManufacturerFilter := L_RecItemMan."Manufacturer code";
                            QtyPerToteFilter := L_RecItemMan."Qty per Tote";
                        end else begin
                            ManufacturerFilter := '';
                            QtyPerToteFilter := 0;
                        end;
                    end else begin
                        ItemDescription := '';
                        ManufacturerFilter := '';
                        QtyPerToteFilter := 0;
                    end;
                end;
            }
            field(ManufacturerFilter; ManufacturerFilter)
            {
                ApplicationArea = All;
                Caption = 'Manufacturer';

                trigger OnLookup(var Text: Text): Boolean
                var
                    L_ItemMan: Record "Item Manufacturer Table";
                    L_ItemManPage: Page "Item Manufacturer Page";
                    L_SourceQuery: Query WarehouseEntryReceive;
                    //L_Events: Codeunit Events;
                    L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
                    L_MfgList: List of [Code[50]];
                    L_MfgCode: Code[50];
                    L_MfgFilter: Text;
                    L_SourceZone: Code[10];
                begin
                    if ItemFilter = '' then
                        Error('Please specify the Item No. before selecting a Manufacturer.');

                    L_SourceZone := L_KamWhseSetupLookup.GetGenDecantZone(CurrentLocationCode);

                    L_SourceQuery.SetFilter(Item_No_, ItemFilter);
                    if CurrentLocationCode <> '' then
                        L_SourceQuery.SetFilter(Location_Code, CurrentLocationCode);
                    if L_SourceZone <> '' then
                        L_SourceQuery.SetFilter(Zone_Code, L_SourceZone);
                    L_SourceQuery.SetFilter(Expiration_Date, '>=%1', WorkDate());
                    L_SourceQuery.SetFilter(L_SourceQuery.Manufacturer_Code, '<>%1', '');
                    L_SourceQuery.SetFilter(Qty_Base, '>%1', 0);
                    L_SourceQuery.Open();
                    while L_SourceQuery.Read() do
                        if not L_MfgList.Contains(L_SourceQuery.Manufacturer_Code) then
                            L_MfgList.Add(L_SourceQuery.Manufacturer_Code);
                    L_SourceQuery.Close();

                    if L_MfgList.Count = 0 then
                        Error('No available stock for Item %1 at Location %2.', ItemFilter, CurrentLocationCode);

                    foreach L_MfgCode in L_MfgList do begin
                        if L_MfgFilter <> '' then
                            L_MfgFilter += '|';
                        L_MfgFilter += L_MfgCode;
                    end;

                    L_ItemMan.Reset();
                    L_ItemMan.SetRange("Item No", ItemFilter);
                    L_ItemMan.SetFilter("Manufacturer code", L_MfgFilter);
                    L_ItemManPage.SetTableView(L_ItemMan);
                    L_ItemManPage.LookupMode(true);
                    if L_ItemManPage.RunModal() = Action::LookupOK then begin
                        L_ItemManPage.GetRecord(L_ItemMan);
                        ManufacturerFilter := L_ItemMan."Manufacturer code";
                        QtyPerToteFilter := L_ItemMan."Qty per Tote";
                        Text := ManufacturerFilter;
                        exit(true);
                    end;
                end;

                trigger OnValidate()
                var
                    L_ItemMan: Record "Item Manufacturer Table";
                begin
                    if ItemFilter = '' then
                        Error('Please specify the Item No. before selecting a Manufacturer.');

                    if ManufacturerFilter <> '' then begin
                        L_ItemMan.Reset();
                        L_ItemMan.SetRange("Item No", ItemFilter);
                        L_ItemMan.SetRange("Manufacturer code", ManufacturerFilter);
                        if L_ItemMan.FindFirst() then
                            QtyPerToteFilter := L_ItemMan."Qty per Tote"
                        else
                            QtyPerToteFilter := 0;
                    end else
                        QtyPerToteFilter := 0;
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
            field(QtyPerToteFilter; QtyPerToteFilter)
            {
                ApplicationArea = All;
                Caption = 'Qty. Per Tote';
                DecimalPlaces = 0 : 5;
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
                    Editable = false;
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
                    Editable = false;
                }
                field("New Package No."; Rec."New Package No.")
                {
                    ApplicationArea = All;
                    //Editable = false; Temporary++
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
                    GenDecantCU: Codeunit "Decant Reclass Mgt.";
                begin
                    if ManufacturerFilter = '' then
                        Error('Please specify the Manufacturer Code.');
                    if DestLocationCode = '' then
                        Error('Please specify the Dest. Location Code.');
                    if QtyPerToteFilter = 0 then
                        Error('Please specify the Qty. Per Tote.');

                    GenDecantCU.CalculateGenDecant(
                        Rec."Journal Template Name",
                        CurrentJnlBatchName,
                        CurrentLocationCode,
                        DestLocationCode,
                        ItemFilter, ManufacturerFilter, QtyPerToteFilter);
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
                    GenDecantCU: Codeunit "Decant Reclass Mgt.";
                    L_DecantDetails: Record "Decant Details";
                begin
                    L_DecantDetails.Reset();
                    L_DecantDetails.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                    L_DecantDetails.SetRange("Location Code", Rec."Location Code");
                    L_DecantDetails.SetRange("Item No.", Rec."Item No.");
                    L_DecantDetails.SetRange("Manufacturer Code", Rec."Manufacturer Code");
                    L_DecantDetails.SetRange("New Package No.", '');
                    if not L_DecantDetails.IsEmpty then
                        Error('Package No. cannot be blank on Line No. %1', L_DecantDetails."Line No.");

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

        // if ItemFilter <> '' then begin
        //     RecItem.Reset();
        //     RecItem.SetRange("No.", ItemFilter);
        //     if RecItem.FindFirst() then begin
        //         ItemDescription := RecItem.Description;
        //         CurrPage.Update();
        //     end else begin
        //         ItemDescription := '';
        //         CurrPage.Update();
        //     end;
        // end else begin
        //     ItemDescription := '';
        //     CurrPage.Update();
        // end;
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
        ManufacturerFilter: Code[100];
        QtyPerToteFilter: Decimal;
        ItemDescription: text[250];
        CurrentJnlBatchName: Code[10];
        CurrentLocationCode: Code[10];
        DestLocationCode: Code[10];
}
