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
                // Sales Orders are always handled via tote information.
                // With tote info  → create one Inventory Pick per tote, then exit.
                // Without tote info → skip; no pick is created.
                if ("Warehouse Request"."Source Document" = "Warehouse Request"."Source Document"::"Sales Order") and CreatePick then begin
                    if HasKnappToteInfo("Warehouse Request"."Source No.") then begin
                        CreateKnappTotePicksForOrder("Warehouse Request");
                        exit;
                    end else
                        CurrReport.Skip();
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
        L_SalesHeader: Record "Sales Header";
        L_Location: Record Location;
        L_WhseActivLineChk: Record "Warehouse Activity Line";
        TempOrigResEntry: Record "Reservation Entry" temporary;
        LocalPickMovement: Codeunit "Create Inventory Pick/Movement";
        NewWhseActivLine: Record "Warehouse Activity Line";
        ToteList: List of [Code[20]];
        ToteNo: Code[20];
        SalesOrderNo: Code[20];
        RemQtyToPickBase: Decimal;
        RemainingBase: Decimal;
        AlreadyPickedBase: Decimal;
        OrderSubtype: Integer;
        NeedPick: Boolean;
    begin
        SalesOrderNo := WhseRequest."Source No.";
        OrderSubtype := L_SalesLine."Document Type"::Order.AsInteger();

        if CheckWhseRequest(WhseRequest) then
            exit;

        if not L_SalesHeader.Get(L_SalesHeader."Document Type"::Order, SalesOrderNo) then
            exit;
        if not L_Location.Get(WhseRequest."Location Code") then
            Clear(L_Location);

        // ── Collect distinct Tote Nos (sorted order from the key) ────────────
        KnappToteInfo.SetRange("Sales Order No.", SalesOrderNo);
        KnappToteInfo.SetCurrentKey("Sales Order No.", "Tote No.");
        if KnappToteInfo.FindSet() then
            repeat
                if not ToteList.Contains(KnappToteInfo."Tote No.") then
                    ToteList.Add(KnappToteInfo."Tote No.");
            until KnappToteInfo.Next() = 0;

        if ToteList.Count = 0 then
            exit;

        // ── One Inventory Pick per tote ──────────────────────────────────────
        //
        // The standard AutoCreatePickOrMove CANNOT be used to split a single
        // Sales Line across several picks: CreatePickOrMoveFromSales skips any
        // Sales Line that already has a warehouse activity line anywhere
        // (Warehouse Activity Line.ActivityExists, with no document filter).
        // So once a line is on tote A's pick, tote B can never pick it again.
        //
        // Instead we build one Warehouse Activity Header per tote ourselves and
        // call the PUBLIC RunCreatePickOrMoveLine once per Knapp tote entry —
        // that method does NOT call ActivityExists, so the same Sales Line can
        // appear on several tote picks.
        //
        // Quantity control: for item-tracked lines the codeunit picks the sum
        // of the line's item-tracking "Qty. to Handle (Base)" (the whole lot),
        // NOT the RemQtyToPickBase we pass. Nothing syncs that from Qty. to
        // Ship. So before each call we cap the line's reservation-entry
        // Qty. to Handle to this tote entry's quantity, then restore it.
        // ─────────────────────────────────────────────────────────────────────
        foreach ToteNo in ToteList do begin

            // Per-LINE guard: a tote may need more than one pick over time — e.g.
            // one line had no stock when the tote first arrived, got stock later.
            // So we only skip the lines of this tote that are ALREADY picked for
            // this tote; if at least one line still needs picking we (re)create a
            // pick. Two picks for the same order + tote are allowed when the lines
            // differ.
            NeedPick := false;
            KnappToteInfo.Reset();
            KnappToteInfo.SetRange("Sales Order No.", SalesOrderNo);
            KnappToteInfo.SetRange("Tote No.", ToteNo);
            if KnappToteInfo.FindSet() then
                repeat
                    if (KnappToteInfo.Quantity > 0) and
                       not HasExistingTotePickLine(SalesOrderNo, OrderSubtype, KnappToteInfo."Sales Order Line No.", ToteNo)
                    then
                        NeedPick := true;
                until KnappToteInfo.Next() = 0;
            if not NeedPick then
                continue;

            // Create the pick header for this tote (No. assigned from No. Series)
            InitWhseActivHeader(L_SalesLine);
            WarehouseActivityHeader."No." := '';
            WarehouseActivityHeader.Insert(true);
            WarehouseActivityHeader."Source Document" := WhseRequest."Source Document";
            WarehouseActivityHeader."Source Type" := WhseRequest."Source Type";
            WarehouseActivityHeader."Source Subtype" := WhseRequest."Source Subtype";
            WarehouseActivityHeader."Source No." := WhseRequest."Source No.";
            WarehouseActivityHeader."Location Code" := WhseRequest."Location Code";
            WarehouseActivityHeader."Destination Type" := WhseRequest."Destination Type";
            WarehouseActivityHeader."Destination No." := WhseRequest."Destination No.";
            WarehouseActivityHeader."Shipment Date" := WhseRequest."Shipment Date";
            WarehouseActivityHeader."Tote No. NDPP" := ToteNo;
            WarehouseActivityHeader.Modify();

            // Fresh codeunit, pointed at this tote's header
            Clear(LocalPickMovement);
            LocalPickMovement.SetInvtMovement(false);
            LocalPickMovement.SetReportGlobals(PrintDocument, ShowError, ReservedFromStock);
            LocalPickMovement.SetSourceDocDetailsFilter("Warehouse Source Filter");
            LocalPickMovement.SetWhseRequest(WhseRequest, true);
            LocalPickMovement.SetWhseActivHeader(WarehouseActivityHeader);
            LocalPickMovement.FindNextLineNo();

            // One pick line per tote entry, limited to the tote's quantity AND to
            // the quantity still left on the sales line (outstanding minus what is
            // already on other picks), so the picks never exceed the order qty.
            KnappToteInfo.Reset();
            KnappToteInfo.SetRange("Sales Order No.", SalesOrderNo);
            KnappToteInfo.SetRange("Tote No.", ToteNo);
            if KnappToteInfo.FindSet() then
                repeat
                    if (KnappToteInfo.Quantity > 0) and
                       L_SalesLine.Get(L_SalesLine."Document Type"::Order, SalesOrderNo, KnappToteInfo."Sales Order Line No.") and
                       (L_SalesLine.Type = L_SalesLine.Type::Item) and
                       not HasExistingTotePickLine(SalesOrderNo, OrderSubtype, KnappToteInfo."Sales Order Line No.", ToteNo)
                    then begin
                        AlreadyPickedBase := AlreadyPickedQtyBase(SalesOrderNo, OrderSubtype, KnappToteInfo."Sales Order Line No.");
                        RemainingBase := L_SalesLine."Outstanding Qty. (Base)" - AlreadyPickedBase;

                        RemQtyToPickBase := KnappToteInfo.Quantity * L_SalesLine."Qty. per Unit of Measure";
                        if RemQtyToPickBase > RemainingBase then
                            RemQtyToPickBase := RemainingBase;

                        if RemQtyToPickBase > 0 then begin
                            // Cap item-tracking Qty. to Handle to the pick qty
                            LimitTrackingToToteQty(L_SalesLine, RemQtyToPickBase, TempOrigResEntry);

                            BuildToteActivLine(NewWhseActivLine, L_SalesLine, WarehouseActivityHeader, L_SalesHeader, L_Location."Bin Mandatory");
                            L_SalesLine.CalcFields("Reserved Quantity");
                            LocalPickMovement.RunCreatePickOrMoveLine(
                                NewWhseActivLine, RemQtyToPickBase, L_SalesLine."Outstanding Qty. (Base)", L_SalesLine."Reserved Quantity" <> 0);

                            // Restore the original item-tracking Qty. to Handle
                            RestoreTracking(TempOrigResEntry);
                        end;
                    end;
                until KnappToteInfo.Next() = 0;

            // Keep the pick only if lines were actually created
            L_WhseActivLineChk.Reset();
            L_WhseActivLineChk.SetRange("Activity Type", WarehouseActivityHeader.Type);
            L_WhseActivLineChk.SetRange("No.", WarehouseActivityHeader."No.");
            if L_WhseActivLineChk.IsEmpty() then
                WarehouseActivityHeader.Delete(true)
            else begin
                PickCounter += 1;
                TotalPickCounter += 1;
                DocumentCreated := true;
                if PrintDocument then
                    InsertTempWhseActivHdr();
            end;
            Commit();
        end;
    end;

    local procedure HasExistingTotePickLine(SalesOrderNo: Code[20]; SourceSubtype: Integer; LineNo: Integer; ToteNo: Code[20]): Boolean
    var
        L_WhseActivLine: Record "Warehouse Activity Line";
        L_WhseActivHeader: Record "Warehouse Activity Header";
    begin
        L_WhseActivLine.SetRange("Activity Type", L_WhseActivLine."Activity Type"::"Invt. Pick");
        L_WhseActivLine.SetRange("Source Type", Database::"Sales Line");
        L_WhseActivLine.SetRange("Source Subtype", SourceSubtype);
        L_WhseActivLine.SetRange("Source No.", SalesOrderNo);
        L_WhseActivLine.SetRange("Source Line No.", LineNo);
        if L_WhseActivLine.FindSet() then
            repeat
                if L_WhseActivHeader.Get(L_WhseActivHeader.Type::"Invt. Pick", L_WhseActivLine."No.") then
                    if L_WhseActivHeader."Tote No. NDPP" = ToteNo then
                        exit(true);
            until L_WhseActivLine.Next() = 0;
        exit(false);
    end;

    local procedure AlreadyPickedQtyBase(SalesOrderNo: Code[20]; SourceSubtype: Integer; LineNo: Integer): Decimal
    var
        L_WhseActivLine: Record "Warehouse Activity Line";
    begin
        // Total quantity for this sales line already sitting on open inventory
        // picks (any tote), so a later tote cannot pick more than what is left.
        L_WhseActivLine.SetRange("Activity Type", L_WhseActivLine."Activity Type"::"Invt. Pick");
        L_WhseActivLine.SetRange("Source Type", Database::"Sales Line");
        L_WhseActivLine.SetRange("Source Subtype", SourceSubtype);
        L_WhseActivLine.SetRange("Source No.", SalesOrderNo);
        L_WhseActivLine.SetRange("Source Line No.", LineNo);
        L_WhseActivLine.CalcSums("Qty. Outstanding (Base)");
        exit(L_WhseActivLine."Qty. Outstanding (Base)");
    end;

    local procedure LimitTrackingToToteQty(_SalesLine: Record "Sales Line"; ToteQtyBase: Decimal; var TempOrigResEntry: Record "Reservation Entry" temporary)
    var
        ResEntry: Record "Reservation Entry";
        RemBase: Decimal;
        AllocBase: Decimal;
        Sign: Integer;
    begin
        TempOrigResEntry.Reset();
        TempOrigResEntry.DeleteAll();
        RemBase := ToteQtyBase;

        ResEntry.SetRange("Source Type", Database::"Sales Line");
        ResEntry.SetRange("Source Subtype", _SalesLine."Document Type".AsInteger());
        ResEntry.SetRange("Source ID", _SalesLine."Document No.");
        ResEntry.SetRange("Source Ref. No.", _SalesLine."Line No.");
        if ResEntry.FindSet() then
            repeat
                if ResEntry.TrackingExists() then begin
                    // snapshot for restore
                    TempOrigResEntry := ResEntry;
                    TempOrigResEntry.Insert();

                    Sign := 1;
                    if ResEntry."Qty. to Handle (Base)" < 0 then
                        Sign := -1;

                    AllocBase := Abs(ResEntry."Qty. to Handle (Base)");
                    if AllocBase > RemBase then
                        AllocBase := RemBase;
                    RemBase -= AllocBase;

                    ResEntry."Qty. to Handle (Base)" := Sign * AllocBase;
                    ResEntry.Modify();
                end;
            until ResEntry.Next() = 0;
    end;

    local procedure RestoreTracking(var TempOrigResEntry: Record "Reservation Entry" temporary)
    var
        ResEntry: Record "Reservation Entry";
    begin
        if TempOrigResEntry.FindSet() then
            repeat
                if ResEntry.Get(TempOrigResEntry."Entry No.", TempOrigResEntry.Positive) then begin
                    ResEntry."Qty. to Handle (Base)" := TempOrigResEntry."Qty. to Handle (Base)";
                    ResEntry.Modify();
                end;
            until TempOrigResEntry.Next() = 0;
    end;

    local procedure BuildToteActivLine(var NewWhseActivLine: Record "Warehouse Activity Line"; _SalesLine: Record "Sales Line"; _WhseActivHeader: Record "Warehouse Activity Header"; _SalesHeader: Record "Sales Header"; BinMandatory: Boolean)
    begin
        // Mirrors the line template built inside codeunit 7322
        // CreatePickOrMoveFromSales, so RunCreatePickOrMoveLine behaves exactly
        // as the standard pick creation would for this Sales Line.
        NewWhseActivLine.Init();
        NewWhseActivLine."Activity Type" := _WhseActivHeader.Type;
        NewWhseActivLine."No." := _WhseActivHeader."No.";
        if BinMandatory then
            NewWhseActivLine."Action Type" := NewWhseActivLine."Action Type"::Take;
        NewWhseActivLine.SetSource(Database::"Sales Line", _SalesLine."Document Type".AsInteger(), _SalesLine."Document No.", _SalesLine."Line No.", 0);
        NewWhseActivLine."Location Code" := _SalesLine."Location Code";
        NewWhseActivLine."Bin Code" := _SalesLine."Bin Code";
        NewWhseActivLine."Item No." := _SalesLine."No.";
        NewWhseActivLine."Variant Code" := _SalesLine."Variant Code";
        NewWhseActivLine."Unit of Measure Code" := _SalesLine."Unit of Measure Code";
        NewWhseActivLine."Qty. per Unit of Measure" := _SalesLine."Qty. per Unit of Measure";
        NewWhseActivLine."Qty. Rounding Precision" := _SalesLine."Qty. Rounding Precision";
        NewWhseActivLine."Qty. Rounding Precision (Base)" := _SalesLine."Qty. Rounding Precision (Base)";
        NewWhseActivLine.Description := _SalesLine.Description;
        NewWhseActivLine."Description 2" := _SalesLine."Description 2";
        NewWhseActivLine."Due Date" := _SalesLine."Planned Shipment Date";
        NewWhseActivLine."Shipping Advice" := _SalesHeader."Shipping Advice";
        NewWhseActivLine."Shipping Agent Code" := _SalesLine."Shipping Agent Code";
        NewWhseActivLine."Shipping Agent Service Code" := _SalesLine."Shipping Agent Service Code";
        NewWhseActivLine."Shipment Method Code" := _SalesHeader."Shipment Method Code";
        NewWhseActivLine."Destination Type" := NewWhseActivLine."Destination Type"::Customer;
        NewWhseActivLine."Destination No." := _SalesHeader."Sell-to Customer No.";
        NewWhseActivLine."Source Document" := NewWhseActivLine."Source Document"::"Sales Order";
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
