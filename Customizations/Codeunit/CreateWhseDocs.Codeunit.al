namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Warehouse.Request;
using System.Threading;
using Microsoft.Inventory.Location;

codeunit 99999 "Create Whse. Docs"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()

    begin
        IF (STRPOS(Rec."Parameter String", ';')) > 0 THEN begin
            StartParameter := COPYSTR(Rec."Parameter String", 1, (STRPOS(Rec."Parameter String", ';') - 1));
            RunType := COPYSTR(Rec."Parameter String", (STRPOS(Rec."Parameter String", ';') + 1), (STRLEN(Rec."Parameter String") - STRPOS(Rec."Parameter String", ';')));
        end;

        CASE RunType OF
            Lbl_CreateReceipts:
                this.triggerWhseReceiptCreation(); // ;CreateReceipts //StartParameter;RunType
            Lbl_CreateInvtPicks:
                this.triggerInvtPickCreation(); // ;CreateInvtPicks //StartParameter;RunType

        end;


    end;

    #region Create Warehouse Recipts++
    local procedure triggerWhseReceiptCreation()
    var
        L_PurchaseHeader: Record "Purchase Header";
    begin
        L_PurchaseHeader.SetRange("Document Type", L_PurchaseHeader."Document Type"::Order);
        L_PurchaseHeader.SetRange(Status, L_PurchaseHeader.Status::Released);
        //L_PurchaseHeader.SetRange("No.", '106079');
        if L_PurchaseHeader.FindSet(true) then
            repeat
                if NeedsWhseReceipt(L_PurchaseHeader) then begin
                    ClearLastError();
                    if TryCreate(L_PurchaseHeader) then begin
                        if L_PurchaseHeader."Whse. Receipt Error" <> '' then begin
                            L_PurchaseHeader."Whse. Receipt Error" := '';
                            L_PurchaseHeader.Modify();
                        end;
                    end else begin
                        L_PurchaseHeader."Whse. Receipt Error" := CopyStr(GetLastErrorText(), 1, MaxStrLen(L_PurchaseHeader."Whse. Receipt Error"));
                        L_PurchaseHeader.Modify();
                    end;
                end;
            until L_PurchaseHeader.Next() = 0;
    end;

    [TryFunction]
    local procedure TryCreate(var PH: Record "Purchase Header")
    var
        GetSourceDocInbound: Codeunit "Get Source Doc. Inbound";
    begin
        // Hide-dialog variant: builds the Warehouse Receipt silently and does
        // not open the created receipt page (vanilla CreateFromPurchOrder calls
        // ShowDialog which is unwanted in a Job Queue / batch context).
        GetSourceDocInbound.CreateFromPurchOrderHideDialog(PH);
    end;

    // Mirrors the vanilla gate used by codeunit "Whse.-Purchase Release":
    //   - Document Type must be Order or Return Order
    //   - Header must be Released (so the standard Whse. Requests already exist)
    //   - At least one outstanding inventoriable Item line, non-drop-shipment,
    //     on a location where Location.RequireReceive is true.
    // No "is there already a Whse. Request?" gate — vanilla doesn't have one;
    // duplicate-protection is handled by Get Source Doc. Inbound itself.
    local procedure NeedsWhseReceipt(PH: Record "Purchase Header"): Boolean
    var
        PL: Record "Purchase Line";
        Location: Record Location;
    begin
        if not (PH."Document Type" in [PH."Document Type"::Order, PH."Document Type"::"Return Order"]) then
            exit(false);
        // if PH.Status <> PH.Status::Released then
        //     exit(false);

        PL.SetRange("Document Type", PH."Document Type");
        PL.SetRange("Document No.", PH."No.");
        PL.SetRange(Type, PL.Type::Item);
        PL.SetRange("Drop Shipment", false);
        PL.SetFilter("Outstanding Quantity", '<>0');
        if PL.FindSet() then
            repeat
                if PL.IsInventoriableItem() and not PL.IsWorkCenter() then
                    if Location.RequireReceive(PL."Location Code") then
                        exit(true);
            until PL.Next() = 0;
        exit(false);
    end;
    #endregion Create Warehouse Receipts

    #region Create Inventory Picks

    local procedure triggerInvtPickCreation()
    var
        L_SalesHeader: Record "Sales Header";
    begin
        L_SalesHeader.SetRange("Document Type", L_SalesHeader."Document Type"::Order);
        L_SalesHeader.SetRange(Status, L_SalesHeader.Status::Released);
        if L_SalesHeader.FindSet(true) then
            repeat
                if NeedsInvtPick(L_SalesHeader) then begin
                    ClearLastError();
                    if TryCreate(L_SalesHeader) then begin
                        if L_SalesHeader."Invt. Pick Error" <> '' then begin
                            L_SalesHeader."Invt. Pick Error" := '';
                            L_SalesHeader.Modify();
                        end;
                    end else begin
                        L_SalesHeader."Invt. Pick Error" := CopyStr(GetLastErrorText(), 1, MaxStrLen(L_SalesHeader."Invt. Pick Error"));
                        L_SalesHeader.Modify();
                    end;
                end;
            until L_SalesHeader.Next() = 0;
    end;

    [TryFunction]
    local procedure TryCreate(var SH: Record "Sales Header")
    var
        L_WhseRequest: Record "Warehouse Request";
        L_CreateInvtPutAwayPickMvmt: Report "Create Invt Put-away/Pick/Mvmt";
    begin
        // Filter the Released Whse Request created when the Sales Order was
        // released. Use Source No. = SH."No." for an unambiguous match.
        L_WhseRequest.SetCurrentKey("Source Document", "Source No.");
        L_WhseRequest.SetRange("Source Document", L_WhseRequest."Source Document"::"Sales Order");
        L_WhseRequest.SetRange("Source No.", SH."No.");
        L_WhseRequest.SetRange("Document Status", L_WhseRequest."Document Status"::Released);

        L_CreateInvtPutAwayPickMvmt.SetTableView(L_WhseRequest);
        // (PutAway, Pick, Movement, PrintDoc, ShowError)
        L_CreateInvtPutAwayPickMvmt.InitializeRequest(false, true, false, false, false);
        L_CreateInvtPutAwayPickMvmt.SuppressMessages(true);
        L_CreateInvtPutAwayPickMvmt.UseRequestPage(false);
        L_CreateInvtPutAwayPickMvmt.RunModal();
    end;

    // Mirrors NeedsWhseReceipt in Cod99951 but for the outbound Inventory Pick
    // gate: Location.RequirePick = true AND Location.RequireShipment = false.
    // When RequireShipment is true, the standard flow uses Warehouse Shipment +
    // Warehouse Pick instead of Inventory Pick.
    local procedure NeedsInvtPick(SH: Record "Sales Header"): Boolean
    var
        SL: Record "Sales Line";
        Location: Record Location;
    begin
        if not (SH."Document Type" in [SH."Document Type"::Order, SH."Document Type"::"Return Order"]) then
            exit(false);
        if SH.Status <> SH.Status::Released then
            exit(false);

        SL.SetRange("Document Type", SH."Document Type");
        SL.SetRange("Document No.", SH."No.");
        SL.SetRange(Type, SL.Type::Item);
        SL.SetRange("Drop Shipment", false);
        SL.SetFilter("Outstanding Qty. (Base)", '<>0');
        if SL.FindSet() then
            repeat
                if SL.IsInventoriableItem() then
                    if Location.RequirePicking(SL."Location Code")
                       and not Location.RequireShipment(SL."Location Code")
                    then
                        exit(true);
            until SL.Next() = 0;
        exit(false);
    end;
    #endregion Create Inventory Picks

    var
        StartParameter: Text;
        RunType: Text;
#pragma warning disable AA0074
        Lbl_CreateReceipts: Label 'CreateReceipts';
#pragma warning restore AA0074
#pragma warning disable AA0074
        Lbl_CreateInvtPicks: Label 'CreateInvtPicks';
#pragma warning restore AA0074
}
