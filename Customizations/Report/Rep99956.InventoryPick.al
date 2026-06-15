report 99956 "Create Invt. Pick"
{
    AccessByPermission = TableData Location = R;
    ApplicationArea = Warehouse;
    Caption = 'Create Invt. Pick';
    ProcessingOnly = true;
    UsageCategory = Tasks;

    dataset
    {
        dataitem("Warehouse Request"; "Warehouse Request")
        {
            DataItemTableView = sorting("Source Document", "Source No.");
            RequestFilterFields = "Source Document", "Source No.", "Location Code";

            trigger OnAfterGetRecord()
            var
                ATOMvmntCreated: Integer;
                TotalATOMvmtToBeCreated: Integer;
                L_SalesLine: Record "Sales Line";
                InvePickCreated: Boolean;
                //MultipleInvePick: Codeunit "Multiple Inve Pick";
                L_Customer: Record Customer;
                L_SalesHeader: Record "Sales Header";
                L_ToteInformation: Record "Knapp Tote Information";
                report7323: Report 7323;
            begin
                Clear(InvePickCreated);
                Window.Update(1, "Source Document");
                Window.Update(2, "Source No.");

                // case Type of
                //     Type::Inbound:
                //         TotalPutAwayCounter += 1;
                //     Type::Outbound:
                //         if CreatePick then
                //             TotalPickCounter += 1
                //         else
                //             TotalMovementCounter += 1;
                // end;

                L_SalesHeader.Reset();
                if "Warehouse Request"."Source Document" = "Warehouse Request"."Source Document"::"Sales Order" then
                    L_SalesHeader.SetRange("Document Type", L_SalesHeader."Document Type"::Order);
                if "Warehouse Request"."Source Document" = "Warehouse Request"."Source Document"::"Sales Return Order" then
                    L_SalesHeader.SetRange("Document Type", L_SalesHeader."Document Type"::"Return Order");
                L_SalesHeader.SetRange("No.", "Warehouse Request"."Source No.");
                if L_SalesHeader.FindFirst() then begin
                    //Not required as per new requirement
                    // if (L_SalesHeader."Order Category" <> L_SalesHeader."Order Category"::Hospital) AND (L_SalesHeader."Order Category" <> L_SalesHeader."Order Category"::Wholesale) AND (L_SalesHeader."Order Category" <> L_SalesHeader."Order Category"::Tender) then begin
                    //     L_SalesHeader.CalcFields("Inv. Pick Exist");
                    //     if L_SalesHeader."Inv. Pick Exist" = true then
                    //         CurrReport.Skip();
                    // end;
                    //Not required as per new requirement

                    //  L_SalesHeader.CalcFields("Inv. Pick Exist");
                    // if L_SalesHeader."Inv. Pick Exist" = true then
                    //  CurrReport.Skip();
                end;

                // ── KNAPP TOTE SECTION ──────────────────────────────────────────────────
                // For Sales Orders that have Knapp Tote Information, create per-tote
                // Inventory Picks using the quantities defined in table 99990.
                // The standard Sales Line / warehouse-class-code loop is bypassed.
                if ("Warehouse Request"."Source Document" = "Warehouse Request"."Source Document"::"Sales Order") and
                   CreatePick and
                   HasKnappToteInfo("Warehouse Request"."Source No.")
                then begin
                    CreateKnappTotePicksForOrder("Warehouse Request");
                    exit;
                end;
                // ── END KNAPP TOTE SECTION ───────────────────────────────────────────────





                L_SalesLine.Reset();
                if "Warehouse Request"."Source Document" = "Warehouse Request"."Source Document"::"Sales Order" then
                    L_SalesLine.SetRange("Document Type", L_SalesLine."Document Type"::Order);
                if "Warehouse Request"."Source Document" = "Warehouse Request"."Source Document"::"Sales Return Order" then
                    L_SalesLine.SetRange("Document Type", L_SalesLine."Document Type"::"Return Order");
                L_SalesLine.SetRange("Document No.", "Warehouse Request"."Source No.");
                L_SalesLine.SetRange(Type, L_SalesLine.Type::Item);
                //L_SalesLine.SetRange("Knapp Line", false);
                //L_SalesLine.SetCurrentKey("Whs. Class Code type");
                L_SalesLine.Ascending(true);
                if L_SalesLine.FindSet() then begin
                    repeat
                        Clear(InvePickCreated);

                        //Default Code+++++
                        if CheckWhseRequest("Warehouse Request") then
                            CurrReport.Skip();

                        if ((Type = Type::Inbound) and (WarehouseActivityHeader.Type <> WarehouseActivityHeader.Type::"Invt. Put-away")) or
                           ((Type = Type::Outbound) and ((WarehouseActivityHeader.Type <> WarehouseActivityHeader.Type::"Invt. Pick") and
                                                         (WarehouseActivityHeader.Type <> WarehouseActivityHeader.Type::"Invt. Movement"))) or
                           ("Source Type" <> WarehouseActivityHeader."Source Type") or
                           ("Source Subtype" <> WarehouseActivityHeader."Source Subtype") or
                           ("Source No." <> WarehouseActivityHeader."Source No.") or
                           ("Location Code" <> WarehouseActivityHeader."Location Code") //or
                                                                                        //(L_SalesLine."Whs. Class Code type" <> WarehouseActivityHeader."Whs. Class Code type")
                        then begin
                            case Type of
                                Type::Inbound:
                                    if not CreateInvtPutAway.CheckSourceDoc("Warehouse Request") then
                                        CurrReport.Skip();
                                Type::Outbound:
                                    begin
                                        //Set the Warehouse Class Code type++
                                        //MultipleInvePick.CallFromCheckSourceDoc(true); // variable declaration commented out above

                                        if not CreateInvtPickMovement.CheckSourceDoc("Warehouse Request") then
                                            CurrReport.Skip();
                                    end;
                            end;



                            InitWhseActivHeader(L_SalesLine);

                            case Type of
                                Type::Inbound:
                                    TotalPutAwayCounter += 1;
                                Type::Outbound:
                                    if CreatePick then
                                        TotalPickCounter += 1
                                    else
                                        TotalMovementCounter += 1;
                            end;
                            InvePickCreated := true;
                        end;

                        case Type of
                            Type::Inbound:
                                begin
                                    CreateInvtPutAway.SetWhseRequest("Warehouse Request", true);
                                    CreateInvtPutAway.AutoCreatePutAway(WarehouseActivityHeader);
                                end;
                            Type::Outbound:
                                begin
                                    CreateInvtPickMovement.SetWhseRequest("Warehouse Request", true);
                                    CreateInvtPickMovement.AutoCreatePickOrMove(WarehouseActivityHeader);
                                end;
                        end;

                        if (WarehouseActivityHeader."No." <> '') AND (InvePickCreated = true) then begin
                            DocumentCreated := true;
                            case Type of
                                Type::Inbound:
                                    PutAwayCounter := PutAwayCounter + 1;
                                Type::Outbound:
                                    if CreatePick then begin
                                        PickCounter := PickCounter + 1;

                                        CreateInvtPickMovement.GetATOMovementsCounters(ATOMvmntCreated, TotalATOMvmtToBeCreated);
                                        MovementCounter += ATOMvmntCreated;
                                        TotalMovementCounter += TotalATOMvmtToBeCreated;
                                    end else
                                        MovementCounter += 1;
                            end;
                            if PrintDocument then
                                InsertTempWhseActivHdr();
                            Commit();
                        end;
                    //Default Code-----
                    until L_SalesLine.Next() = 0;
                end;
            end;

            trigger OnPostDataItem()
            var
                ExpiredItemMessageText: Text[100];
                Msg: Text;
            begin
                ExpiredItemMessageText := CreateInvtPickMovement.GetExpiredItemMessage();
                if TempWarehouseActivityHeader.Find('-') then
                    PrintNewDocuments();

                Window.Close();
                if not SuppressMessagesState then
                    if DocumentCreated then begin
                        if PutAwayCounter > 0 then
                            AddToText(Msg, StrSubstNo(Text005, WarehouseActivityHeader.Type::"Invt. Put-away", PutAwayCounter, TotalPutAwayCounter));
                        if PickCounter > 0 then
                            AddToText(Msg, StrSubstNo(Text005, WarehouseActivityHeader.Type::"Invt. Pick", PickCounter, TotalPickCounter));
                        if MovementCounter > 0 then
                            AddToText(Msg, StrSubstNo(Text005, WarehouseActivityHeader.Type::"Invt. Movement", MovementCounter, TotalMovementCounter));

                        if CreatePutAway or CreatePick then
                            Msg += ExpiredItemMessageText;

                        Message(Msg);
                    end else begin
                        Msg := Text004 + ' ' + ExpiredItemMessageText;
                        Message(Msg);
                    end;
            end;

            trigger OnPreDataItem()
            begin
                if CreatePutAway and not (CreatePick or CreateMovement) then
                    SetRange(Type, Type::Inbound);
                if not CreatePutAway and (CreatePick or CreateMovement) then
                    SetRange(Type, Type::Outbound);

                Window.Open(
                  Text001 +
                  Text002 +
                  Text003);

                DocumentCreated := false;

                if CreatePick or CreateMovement then
                    CreateInvtPickMovement.SetReportGlobals(PrintDocument, ShowError, ReservedFromStock);

                CreateInvtPickMovement.SetSourceDocDetailsFilter("Warehouse Source Filter");
                CreateInvtPutAway.SetSourceDocDetailsFilter("Warehouse Source Filter");
            end;
        }
        dataitem("Warehouse Source Filter"; "Warehouse Source Filter")
        {
            DataItemTableView = sorting(Type, Code);
            RequestFilterFields = "Item No. Filter", "Variant Code Filter", "Shipment Date Filter", "Receipt Date Filter", "Job No.", "Job Task No. Filter", "Prod. Order No.", "Prod. Order Line No. Filter";
            RequestFilterHeading = 'Document details';
            UseTemporary = true;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group("Warehouse Documents")
                {
                    Caption = 'Warehouse Documents';

                    field(CreateInventorytPutAway; CreatePutAway)
                    {
                        Caption = 'Create Invt. Put-Away';
                        ToolTip = 'Specifies if you want to create inventory put-away documents for all source documents that are included in the filter and for which a put-away document is appropriate.';
                        ApplicationArea = All;
                        trigger OnValidate()
                        begin
                            if not (CreatePick or CreateMovement) then
                                ReservedFromStock := ReservedFromStock::" ";
                        end;
                    }
                    field(CInvtPick; CreatePick)
                    {
                        Caption = 'Create Invt. Pick';
                        ToolTip = 'Specifies if you want to create inventory pick documents for all source documents that are included in the filter and for which a pick document is appropriate.';
                        ApplicationArea = All;
                        trigger OnValidate()
                        begin
                            CreateMovement := false;
                            if not (CreatePick or CreateMovement) then
                                ReservedFromStock := ReservedFromStock::" ";
                        end;
                    }
                    field(CInvtMvmt; CreateMovement)
                    {
                        Caption = 'Create Invt. Movement';
                        ToolTip = 'Specifies if you want to create inventory movement documents for all source documents that are included in the filter and for which a movement document is appropriate.';
                        ApplicationArea = All;
                        trigger OnValidate()
                        begin
                            CreatePick := false;
                            if not (CreatePick or CreateMovement) then
                                ReservedFromStock := ReservedFromStock::" ";
                        end;
                    }
                }
                group(Options)
                {
                    Caption = 'Options';

                    field("Reserved From Stock"; ReservedFromStock)
                    {
                        Caption = 'Reserved from stock';
                        ToolTip = 'Specifies if you want to include only source document lines that are fully or partially reserved from current stock.';
                        ValuesAllowed = " ", "Full and Partial", Full;
                        ApplicationArea = All;
                        trigger OnValidate()
                        begin
                            if CreatePutAway and not (CreatePick or CreateMovement) then
                                ReservedFromStock := ReservedFromStock::" ";
                        end;
                    }
                    field(PrintDocument; PrintDocument)
                    {
                        Caption = 'Print Document';
                        ToolTip = 'Specifies if you want the document to be printed.';
                        ApplicationArea = All;
                    }
                    field(ShowError; ShowError)
                    {
                        Caption = 'Show Error';
                        ToolTip = 'Specifies if the report shows error information.';
                        ApplicationArea = All;
                    }
                }
            }
        }

        actions
        {
        }

        trigger OnOpenPage()
        begin
            OnBeforeOpenPage();
        end;
    }

    labels
    {
    }

    trigger OnPostReport()
    begin
        TempWarehouseActivityHeader.DeleteAll();
    end;

    trigger OnPreReport()
    begin
        CreatePick := true; //This is for Job Queue (Codunit 90542)

        if not (CreatePutAway or CreatePick or CreateMovement) then
            Error(Text008);

        CreateInvtPickMovement.SetInvtMovement(CreateMovement);
    end;

    var
        CreateInvtPutAway: Codeunit "Create Inventory Put-away";
        CreateInvtPickMovement: Codeunit "Create Inventory Pick/Movement";
        WhseDocPrint: Codeunit "Warehouse Document-Print";
        Window: Dialog;
        DocumentCreated: Boolean;
        PutAwayCounter: Integer;
        PickCounter: Integer;
        MovementCounter: Integer;
        TotalPutAwayCounter: Integer;
        TotalPickCounter: Integer;
        TotalMovementCounter: Integer;

        Text001: Label 'Creating Inventory Activities...\\';
        Text002: Label 'Source Type     #1##########\';
        Text003: Label 'Source No.      #2##########';
        Text004: Label 'There is nothing to create.';
        Text005: Label 'Number of %1 activities created: %2 out of a total of %3.';
        Text006: Label '%1\\%2', Locked = true;
        Text008: Label 'You must select Create Invt. Put-away, Create Invt. Pick, or Create Invt. Movement.';

    protected var
        WarehouseActivityHeader: Record "Warehouse Activity Header";
        TempWarehouseActivityHeader: Record "Warehouse Activity Header" temporary;
        ReservedFromStock: Enum "Reservation From Stock";
        CreatePutAway: Boolean;
        CreatePick: Boolean;
        CreateMovement: Boolean;
        PrintDocument: Boolean;
        ShowError: Boolean;
        SuppressMessagesState: Boolean;

    local procedure InitWhseActivHeader(_SalesLine: Record "Sales Line")
    var
        L_SalesHeader: Record "Sales Header";
        L_ShippingAgentService: Record "Shipping Agent Services";
    begin
        with WarehouseActivityHeader do begin
            Init();
            case "Warehouse Request".Type of
                "Warehouse Request".Type::Inbound:
                    Type := Type::"Invt. Put-away";
                "Warehouse Request".Type::Outbound:
                    if CreatePick then
                        Type := Type::"Invt. Pick"
                    else
                        Type := Type::"Invt. Movement";
            end;
            "No." := '';
            "Location Code" := "Warehouse Request"."Location Code";
            //"Whs. Class Code type" := _SalesLine."Whs. Class Code type";

            L_SalesHeader.Reset();
            L_SalesHeader.SetRange("No.", _SalesLine."Document No.");
            L_SalesHeader.SetRange("Document Type", _SalesLine."Document Type");
            if L_SalesHeader.FindFirst() then begin
                // "Work Description" := L_SalesHeader.GetWorkDescription();

                L_ShippingAgentService.Reset();
                L_ShippingAgentService.SetRange("Shipping Agent Code", L_SalesHeader."Shipping Agent Code");
                L_ShippingAgentService.SetRange(Code, L_SalesHeader."Shipping Agent Service Code");
                if L_ShippingAgentService.FindFirst() then begin
                    //  Shift := L_ShippingAgentService.Shift;
                    // "Departure Time" := L_ShippingAgentService."Departure Time";
                end;
            end;


        end;

        OnAfterInitWhseActivHeader(WarehouseActivityHeader, "Warehouse Request");
    end;

    local procedure InsertTempWhseActivHdr()
    begin
        TempWarehouseActivityHeader.Init();
        TempWarehouseActivityHeader := WarehouseActivityHeader;
        TempWarehouseActivityHeader.Insert();
    end;

    local procedure PrintNewDocuments()
    begin
        with TempWarehouseActivityHeader do
            repeat
                case Type of
                    Type::"Invt. Put-away":
                        WhseDocPrint.PrintInvtPutAwayHeader(TempWarehouseActivityHeader, false);
                    Type::"Invt. Pick":
                        WhseDocPrint.PrintInvtPickHeader(TempWarehouseActivityHeader, false);
                    Type::"Invt. Movement":
                        WhseDocPrint.PrintInvtMovementHeader(TempWarehouseActivityHeader, false);
                end;
            until Next() = 0;
    end;

    local procedure CheckWhseRequest(var WhseRequest: Record "Warehouse Request") SkipRecord: Boolean
    var
        SalesHeader: Record "Sales Header";
        TransferHeader: Record "Transfer Header";
        GetSrcDocOutbound: Codeunit "Get Source Doc. Outbound";
        IsHandled: Boolean;
        L_Customer: Record Customer;
        L_SalesHeader: Record "Sales Header";
    begin
        IsHandled := false;
        OnBeforeCheckWhseRequest(WhseRequest, ShowError, SkipRecord, IsHandled);
        if IsHandled then
            exit(SkipRecord);

        // //Skip If customer is blocked++
        // L_SalesHeader.Reset();
        // L_SalesHeader.SetRange("No.", WhseRequest."Source No.");
        // if WhseRequest."Source Document" = WhseRequest."Source Document"::"Sales Order" then
        //     L_SalesHeader.SetRange("Document Type", L_SalesHeader."Document Type"::Order);
        // if WhseRequest."Source Document" = WhseRequest."Source Document"::"Sales Return Order" then
        //     L_SalesHeader.SetRange("Document Type", L_SalesHeader."Document Type"::"Return Order");
        // if L_SalesHeader.FindFirst() then begin
        //     L_Customer.Reset();
        //     L_Customer.SetRange("No.", L_SalesHeader."Sell-to Customer No.");
        //     if L_Customer.FindFirst() then begin
        //         if L_Customer.Blocked <> L_Customer.Blocked::" " then
        //             SkipRecord := true;
        //     end;
        // end;

        if WhseRequest."Document Status" <> WhseRequest."Document Status"::Released then
            SkipRecord := true
        else
            if (WhseRequest.Type = WhseRequest.Type::Outbound) and
                (WhseRequest."Shipping Advice" = WhseRequest."Shipping Advice"::Complete)
            then
                case WhseRequest."Source Type" of
                    Database::"Sales Line":
                        if WhseRequest."Source Subtype" = WhseRequest."Source Subtype"::"1" then begin
                            SkipRecord := not SalesHeader.Get(SalesHeader."Document Type"::Order, WhseRequest."Source No.");
                            if not SkipRecord then
                                SkipRecord := GetSrcDocOutbound.CheckSalesHeader(SalesHeader, ShowError);
                        end;
                    Database::"Transfer Line":
                        begin
                            SkipRecord := not TransferHeader.Get(WhseRequest."Source No.");
                            if not SkipRecord then
                                SkipRecord := GetSrcDocOutbound.CheckTransferHeader(TransferHeader, ShowError);
                        end;
                end;
        OnAfterCheckWhseRequest(WhseRequest, SkipRecord);
    end;

    procedure InitializeRequest(NewCreateInvtPutAway: Boolean; NewCreateInvtPick: Boolean; NewCreateInvtMovement: Boolean; NewPrintDocument: Boolean; NewShowError: Boolean)
    begin
        CreatePutAway := NewCreateInvtPutAway;
        CreatePick := NewCreateInvtPick;
        CreateMovement := NewCreateInvtMovement;
        PrintDocument := NewPrintDocument;
        ShowError := NewShowError;
    end;

    procedure SuppressMessages(NewState: Boolean)
    begin
        SuppressMessagesState := NewState;
    end;

    local procedure AddToText(var OrigText: Text; Addendum: Text)
    begin
        if OrigText = '' then
            OrigText := Addendum
        else
            OrigText := StrSubstNo(Text006, OrigText, Addendum);
    end;

    procedure GetMovementCounters(var MovementsCreated: Integer; var TotalMovementsToBeCreated: Integer)
    begin
        MovementsCreated := MovementCounter;
        TotalMovementsToBeCreated := TotalMovementCounter;
    end;

    // ── KNAPP TOTE PROCEDURES ────────────────────────────────────────────────

    local procedure HasKnappToteInfo(SalesOrderNo: Code[20]): Boolean
    var
        KnappToteInfo: Record "Knapp Tote Information";
    begin
        KnappToteInfo.SetRange("Sales Order No.", SalesOrderNo);
        exit(not KnappToteInfo.IsEmpty());
    end;

    local procedure CreateKnappTotePicksForOrder(var WhseRequest: Record "Warehouse Request")
    var
        KnappToteInfo: Record "Knapp Tote Information";
        L_SalesLine: Record "Sales Line";
        SavedQtyToShip: Dictionary of [Integer, Decimal];
        SavedQtyToShipBase: Dictionary of [Integer, Decimal];
        CumulativeQty: Dictionary of [Integer, Decimal];
        ToteList: List of [Code[20]];
        ToteNo: Code[20];
        SalesOrderNo: Code[20];
        CumQty: Decimal;
    begin
        SalesOrderNo := WhseRequest."Source No.";

        // Gate checks — called ONCE before the tote loop.
        // CheckSourceDoc must NOT be called per-tote: after the first pick is
        // committed the codeunit's internal state for this warehouse request is
        // consumed and subsequent calls return false, silently skipping totes.
        if CheckWhseRequest(WhseRequest) then
            exit;
        if not CreateInvtPickMovement.CheckSourceDoc(WhseRequest) then
            exit;

        // ── Save original Qty. to Ship for all item Sales Lines ──────────────
        L_SalesLine.SetRange("Document Type", L_SalesLine."Document Type"::Order);
        L_SalesLine.SetRange("Document No.", SalesOrderNo);
        L_SalesLine.SetRange(Type, L_SalesLine.Type::Item);
        if L_SalesLine.FindSet() then
            repeat
                SavedQtyToShip.Add(L_SalesLine."Line No.", L_SalesLine."Qty. to Ship");
                SavedQtyToShipBase.Add(L_SalesLine."Line No.", L_SalesLine."Qty. to Ship (Base)");
            until L_SalesLine.Next() = 0;

        // ── Collect distinct Tote Nos (sorted order from the key) ────────────
        KnappToteInfo.SetRange("Sales Order No.", SalesOrderNo);
        KnappToteInfo.SetCurrentKey("Sales Order No.", "Tote No.");
        if KnappToteInfo.FindSet() then
            repeat
                if not ToteList.Contains(KnappToteInfo."Tote No.") then
                    ToteList.Add(KnappToteInfo."Tote No.");
            until KnappToteInfo.Next() = 0;

        if ToteList.Count = 0 then begin
            RestoreSalesLineQty(SalesOrderNo, SavedQtyToShip, SavedQtyToShipBase);
            exit;
        end;

        // ── One Inventory Pick per tote  (CUMULATIVE APPROACH) ───────────────
        //
        // When the same Sales Line spans multiple totes, BC deducts
        // Qty. Pick Outstanding (picks already created) from Qty. to Ship
        // when deciding how much to pick next. Setting Qty. to Ship to the
        // running cumulative total ensures:
        //
        //   BC pick qty = Qty. to Ship  -  Qty. Pick Outstanding
        //               = (all prev totes + this tote)  -  (all prev totes)
        //               = this tote's quantity   ✓
        //
        // Lines not yet assigned to any tote stay at cumulative = 0, so BC
        // skips them entirely.
        //
        // Example with the test data (Sales Order 101037):
        //   Tote 50000 → cumulative {10000:1, 20000:3, 30000:1}
        //                BC picks 1/3/1  (Outstanding was 0) ✓
        //   Tote 50001 → cumulative {10000:2, 20000:3, 30000:1}
        //                BC picks (2-1)=1 for line 10000, 0 for others ✓
        //   Tote 50002 → cumulative {10000:2, 20000:3, 30000:2}
        //                BC picks (2-2)=0 for line 10000,
        //                         (2-1)=1 for line 30000 ✓
        // ─────────────────────────────────────────────────────────────────────
        foreach ToteNo in ToteList do begin

            // Step 1 — add this tote's quantities into the running cumulative
            KnappToteInfo.Reset();
            KnappToteInfo.SetRange("Sales Order No.", SalesOrderNo);
            KnappToteInfo.SetRange("Tote No.", ToteNo);
            if KnappToteInfo.FindSet() then
                repeat
                    CumQty := 0;
                    if CumulativeQty.ContainsKey(KnappToteInfo."Sales Order Line No.") then
                        CumulativeQty.Get(KnappToteInfo."Sales Order Line No.", CumQty);
                    CumQty += KnappToteInfo.Quantity;
                    if CumulativeQty.ContainsKey(KnappToteInfo."Sales Order Line No.") then
                        CumulativeQty.Set(KnappToteInfo."Sales Order Line No.", CumQty)
                    else
                        CumulativeQty.Add(KnappToteInfo."Sales Order Line No.", CumQty);
                until KnappToteInfo.Next() = 0;

            // Step 2 — write cumulative qty to every Sales Line
            //          (lines with no tote entry stay at 0 — BC skips them)
            L_SalesLine.Reset();
            L_SalesLine.SetRange("Document Type", L_SalesLine."Document Type"::Order);
            L_SalesLine.SetRange("Document No.", SalesOrderNo);
            L_SalesLine.SetRange(Type, L_SalesLine.Type::Item);
            if L_SalesLine.FindSet(true) then
                repeat
                    CumQty := 0;
                    if CumulativeQty.ContainsKey(L_SalesLine."Line No.") then
                        CumulativeQty.Get(L_SalesLine."Line No.", CumQty);
                    L_SalesLine."Qty. to Ship" := CumQty;
                    L_SalesLine."Qty. to Ship (Base)" := CumQty * L_SalesLine."Qty. per Unit of Measure";
                    L_SalesLine.Modify(false);
                until L_SalesLine.Next() = 0;

            // Step 3 — get a Sales Line from this tote for InitWhseActivHeader
            KnappToteInfo.Reset();
            KnappToteInfo.SetRange("Sales Order No.", SalesOrderNo);
            KnappToteInfo.SetRange("Tote No.", ToteNo);
            if not KnappToteInfo.FindFirst() then
                continue;
            if not L_SalesLine.Get(L_SalesLine."Document Type"::Order, SalesOrderNo, KnappToteInfo."Sales Order Line No.") then
                continue;

            // Step 4 — initialise pick header and create pick.
            //          CheckSourceDoc is NOT called here — it was called once
            //          before the loop; repeating it per-tote would cause the
            //          codeunit to return false after the first pick and skip
            //          all subsequent totes.
            InitWhseActivHeader(L_SalesLine);
            TotalPickCounter += 1;
            CreateInvtPickMovement.SetWhseRequest(WhseRequest, true);
            CreateInvtPickMovement.AutoCreatePickOrMove(WarehouseActivityHeader);

            // Step 7 — stamp Tote No. and commit
            if WarehouseActivityHeader."No." <> '' then begin
                WarehouseActivityHeader."Tote No. NDPP" := ToteNo;
                WarehouseActivityHeader.Modify(false);
                PickCounter += 1;
                DocumentCreated := true;
                if PrintDocument then
                    InsertTempWhseActivHdr();
                Commit();
            end else
                TotalPickCounter -= 1;

        end;

        // ── Restore original Qty. to Ship on all Sales Lines ─────────────────
        RestoreSalesLineQty(SalesOrderNo, SavedQtyToShip, SavedQtyToShipBase);
        Commit();
    end;

    local procedure RestoreSalesLineQty(SalesOrderNo: Code[20]; var SavedQty: Dictionary of [Integer, Decimal]; var SavedQtyBase: Dictionary of [Integer, Decimal])
    var
        L_SalesLine: Record "Sales Line";
        SavedVal: Decimal;
        SavedValBase: Decimal;
    begin
        L_SalesLine.SetRange("Document Type", L_SalesLine."Document Type"::Order);
        L_SalesLine.SetRange("Document No.", SalesOrderNo);
        L_SalesLine.SetRange(Type, L_SalesLine.Type::Item);
        if L_SalesLine.FindSet(true) then
            repeat
                SavedVal := 0;
                SavedValBase := 0;
                if SavedQty.ContainsKey(L_SalesLine."Line No.") then
                    SavedQty.Get(L_SalesLine."Line No.", SavedVal);
                if SavedQtyBase.ContainsKey(L_SalesLine."Line No.") then
                    SavedQtyBase.Get(L_SalesLine."Line No.", SavedValBase);
                L_SalesLine."Qty. to Ship" := SavedVal;
                L_SalesLine."Qty. to Ship (Base)" := SavedValBase;
                L_SalesLine.Modify(false);
            until L_SalesLine.Next() = 0;
    end;

    // ── END KNAPP TOTE PROCEDURES ─────────────────────────────────────────────

    [IntegrationEvent(false, false)]
    local procedure OnAfterCheckWhseRequest(var WarehouseRequest: Record "Warehouse Request"; var SkipRecord: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterInitWhseActivHeader(var WarehouseActivityHeader: Record "Warehouse Activity Header"; var WarehouseRequest: Record "Warehouse Request")
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnBeforeCheckWhseRequest(var WarehouseRequest: Record "Warehouse Request"; ShowError: Boolean; var SkipRecord: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeOpenPage()
    begin
    end;
}
