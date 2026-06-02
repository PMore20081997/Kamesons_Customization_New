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
            field(G_ItemBarcode; G_ItemBarcode)
            {
                ApplicationArea = All;
                Caption = 'Item Barcode';
                trigger OnValidate()
                var
                    L_ItemRef: Record "Item Reference";
                    L_ItemMan: Record "Item Manufacturer Table";
                    L_Item: Record Item;
                    L_SourceQuery: Query WarehouseEntryReceive;
                    L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
                    L_SourceZone: Code[10];
                    L_FefoMfg: Code[50];
                begin
                    if G_ItemBarcode = '' then
                        exit;

                    L_ItemRef.Reset();
                    L_ItemRef.SetRange("Reference Type", L_ItemRef."Reference Type"::"Bar Code");
                    L_ItemRef.SetRange("Reference No.", G_ItemBarcode);
                    if not L_ItemRef.FindFirst() then begin
                        ItemFilter := '';
                        ItemDescription := '';
                        ManufacturerFilter := '';
                        QtyPerToteFilter := 0;
                        CurrPage.Update();
                        Error('No item found with barcode %1.', G_ItemBarcode);
                    end;

                    if not L_Item.Get(L_ItemRef."Item No.") then
                        Error('Item %1 not found.', L_ItemRef."Item No.");

                    if not (L_Item."Routing Type" in
                            [L_Item."Routing Type"::Flowrack, L_Item."Routing Type"::"Static"])
                    then begin
                        ItemFilter := '';
                        ItemDescription := '';
                        ManufacturerFilter := '';
                        QtyPerToteFilter := 0;
                        CurrPage.Update();
                        Error('Item %1 has Routing Type %2. Decant Screen accepts only Flowrack or Static items.',
                            L_Item."No.", Format(L_Item."Routing Type"));
                    end;

                    ItemFilter := L_ItemRef."Item No.";
                    ItemDescription := L_Item.Description;

                    L_SourceZone := L_KamWhseSetupLookup.GetReceiveFlowrackZone(CurrentLocationCode);

                    L_SourceQuery.SetFilter(Item_No_, ItemFilter);
                    if CurrentLocationCode <> '' then
                        L_SourceQuery.SetFilter(Location_Code, CurrentLocationCode);
                    if L_SourceZone <> '' then
                        L_SourceQuery.SetFilter(Zone_Code, L_SourceZone);
                    L_SourceQuery.SetFilter(Expiration_Date, '>=%1', WorkDate());
                    L_SourceQuery.SetFilter(Manufacturer_Code, '<>%1', '');
                    L_SourceQuery.SetFilter(Qty_Base, '>%1', 0);
                    L_SourceQuery.Open();
                    if L_SourceQuery.Read() then
                        L_FefoMfg := L_SourceQuery.Manufacturer_Code;
                    L_SourceQuery.Close();

                    if L_FefoMfg = '' then
                        Error('No available stock for Item %1 at Location %2.', ItemFilter, CurrentLocationCode);

                    ManufacturerFilter := L_FefoMfg;

                    L_ItemMan.Reset();
                    L_ItemMan.SetRange("Item No", ItemFilter);
                    L_ItemMan.SetRange("Manufacturer code", ManufacturerFilter);
                    if L_ItemMan.FindFirst() then
                        QtyPerToteFilter := L_ItemMan."Qty per Tote"
                    else
                        QtyPerToteFilter := 0;

                    CurrPage.Update();
                end;
            }
            field(ItemFilter; ItemFilter)
            {
                ApplicationArea = All;
                Caption = 'Item No.';

                trigger OnLookup(var Text: Text): Boolean
                var
                    L_Item: Record Item;
                    L_ItemList: Page "Item List";
                    L_SourceQuery: Query WarehouseEntryReceive;
                    L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
                    L_ItemNoList: List of [Code[20]];
                    L_ItemNo: Code[20];
                    L_ItemFilter: Text;
                    L_SourceZone: Code[10];
                begin
                    L_SourceZone := L_KamWhseSetupLookup.GetReceiveFlowrackZone(CurrentLocationCode);

                    if CurrentLocationCode <> '' then
                        L_SourceQuery.SetFilter(Location_Code, CurrentLocationCode);
                    if L_SourceZone <> '' then
                        L_SourceQuery.SetFilter(Zone_Code, L_SourceZone);
                    L_SourceQuery.SetFilter(Expiration_Date, '>=%1', WorkDate());
                    L_SourceQuery.SetFilter(Qty_Base, '>%1', 0);
                    L_SourceQuery.Open();
                    while L_SourceQuery.Read() do
                        if not L_ItemNoList.Contains(L_SourceQuery.Item_No_) then
                            L_ItemNoList.Add(L_SourceQuery.Item_No_);
                    L_SourceQuery.Close();

                    if L_ItemNoList.Count = 0 then
                        Error('No items with available stock at Location %1.', CurrentLocationCode);

                    foreach L_ItemNo in L_ItemNoList do begin
                        if L_ItemFilter <> '' then
                            L_ItemFilter += '|';
                        L_ItemFilter += L_ItemNo;
                    end;

                    L_Item.Reset();
                    L_Item.SetFilter("No.", L_ItemFilter);
                    L_Item.SetFilter("Routing Type", '<>%1', "Item Routing Type NDPP"::BULK);
                    L_ItemList.SetTableView(L_Item);
                    L_ItemList.LookupMode(true);
                    if L_ItemList.RunModal() = Action::LookupOK then begin
                        L_ItemList.GetRecord(L_Item);
                        ItemFilter := L_Item."No.";
                        Text := ItemFilter;
                        CurrPage.Update();
                        exit(true);
                    end;
                end;

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

                    L_SourceZone := L_KamWhseSetupLookup.GetReceiveFlowrackZone(CurrentLocationCode);

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
            action("Calculate Decant")
            {
                ApplicationArea = All;
                Caption = 'Calculate Decant';
                Image = Calculate;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Calculates items to move from the source GEN DECANT zone to the destination GEN DECANT zone, based on empty totes. Works for both Flowrack and Static routing-type items.';

                trigger OnAction()
                var
                    DecantMgt: Codeunit "Decant Reclass Mgt.";
                begin
                    if ManufacturerFilter = '' then
                        Error('Please specify the Manufacturer Code.');
                    if DestLocationCode = '' then
                        Error('Please specify the Dest. Location Code.');
                    if QtyPerToteFilter = 0 then
                        Error('Please specify the Qty. Per Tote.');

                    DecantMgt.CalculateDecant(
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
                    DecantMgt: Codeunit "Decant Reclass Mgt.";
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

                    DecantMgt.RegisterDecant(
                        Rec."Journal Template Name",
                        CurrentJnlBatchName, Rec."Location Code"
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
        G_ItemBarcode: Code[250];
}
