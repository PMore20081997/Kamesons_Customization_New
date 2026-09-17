namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Transfer;
//using Microsoft.Inventory.Reservation;
using Microsoft.Inventory.Requisition;
using Microsoft.Inventory.Ledger;
using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Tracking;
using Microsoft.Warehouse.History;

codeunit 99965 "Kam Reservation Mgt."
{
    Access = Public;

    procedure SetTransferAsDirect(var TransHeader: Record "Transfer Header")
    var
        IsHandled: Boolean;
    begin
        OnBeforeSetTransferAsDirect(TransHeader, IsHandled);
        if IsHandled then
            exit;
        TransHeader."Direct Transfer" := true;
    end;

    procedure CreateLotReservationForTransferLine(var TransLine: Record "Transfer Line"; var ReqLine: Record "Requisition Line")
    var
        IsHandled: Boolean;
    begin
        OnBeforeCreateLotReservationForTransferLine(TransLine, ReqLine, IsHandled);
        if IsHandled then
            exit;

        // Skip if no lot info to attach
        if (ReqLine."Lot No." = '') and (ReqLine."Manufacturer Code" = '') and (ReqLine."Package No." = '') then
            exit;

        CreateReservPair(TransLine, ReqLine);

        TransLine.Validate("Transfer-from Bin Code", ReqLine."From Bin Code");
        TransLine.Validate("Transfer-To Bin Code", ReqLine."Bin Code");
        TransLine.Modify(true);

        OnAfterCreateLotReservationForTransferLine(TransLine, ReqLine);
    end;

    local procedure CreateReservPair(TransLine: Record "Transfer Line"; ReqLine: Record "Requisition Line")
    var
        TempReservEntry: Record "Reservation Entry" temporary;
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservStatus: Enum "Reservation Status";
    begin
        // Source-side (subtype 0)
        TempReservEntry.Init();
        TempReservEntry."Source Type" := Database::"Transfer Line";
        TempReservEntry."Source Subtype" := 0;
        TempReservEntry."Source ID" := TransLine."Document No.";
        TempReservEntry."Source Ref. No." := TransLine."Line No.";
        TempReservEntry."Lot No." := ReqLine."Lot No.";
        TempReservEntry."Package No." := ReqLine."Package No.";
        TempReservEntry."Manufacturer Code" := ReqLine."Manufacturer Code";
        TempReservEntry."Manufacturer Name" := MfrName(TempReservEntry."Manufacturer Code");
        if ReqLine."Lot Expiration Date" <> 0D then
            TempReservEntry."Expiration Date" := ReqLine."Lot Expiration Date";

        CreateReservEntry.CreateReservEntryFor(Database::"Transfer Line", 0, TransLine."Document No.", '', 0, TransLine."Line No.", TransLine."Qty. per Unit of Measure", TransLine.Quantity, TransLine.Quantity, TempReservEntry);
        CreateReservEntry.SetDates(0D, ReqLine."Lot Expiration Date");
        CreateReservEntry.CreateEntry(TransLine."Item No.", TransLine."Variant Code", TransLine."Transfer-from Code", '', 0D, TransLine."Shipment Date", 0, ReservStatus::Surplus);

        // Destination-side (subtype 1)
        Clear(TempReservEntry);
        TempReservEntry.Init();
        TempReservEntry."Source Type" := Database::"Transfer Line";
        TempReservEntry."Source Subtype" := 1;
        TempReservEntry."Source ID" := TransLine."Document No.";
        TempReservEntry."Source Ref. No." := TransLine."Line No.";
        TempReservEntry."Lot No." := ReqLine."Lot No.";
        TempReservEntry."Package No." := ReqLine."Package No.";
        TempReservEntry."Manufacturer Code" := ReqLine."Manufacturer Code";
        TempReservEntry."Manufacturer Name" := MfrName(TempReservEntry."Manufacturer Code");
        if ReqLine."Lot Expiration Date" <> 0D then
            TempReservEntry."Expiration Date" := ReqLine."Lot Expiration Date";

        CreateReservEntry.CreateReservEntryFor(Database::"Transfer Line", 1, TransLine."Document No.", '', 0, TransLine."Line No.", TransLine."Qty. per Unit of Measure", TransLine.Quantity, TransLine.Quantity, TempReservEntry);
        CreateReservEntry.SetDates(0D, ReqLine."Lot Expiration Date");
        CreateReservEntry.CreateEntry(TransLine."Item No.", TransLine."Variant Code", TransLine."Transfer-to Code", '', TransLine."Receipt Date", 0D, 0, ReservStatus::Surplus);
    end;

    procedure EnrichTrackingSpecificationWithManufacturer(var TrackingSpec: Record "Tracking Specification"; var TempTrackingSpec: Record "Tracking Specification" temporary)
    begin
        if TrackingSpec."Manufacturer Code" <> '' then
            exit;
        if TempTrackingSpec."Manufacturer Code" <> '' then begin
            TrackingSpec."Manufacturer Code" := TempTrackingSpec."Manufacturer Code";
            TrackingSpec."Manufacturer Name" := MfrName(TrackingSpec."Manufacturer Code");
            exit;
        end;
        TrackingSpec."Manufacturer Code" :=
            LookupManufacturerCodeByLot(TrackingSpec."Item No.", TrackingSpec."Variant Code", TrackingSpec."Lot No.");
        TrackingSpec."Manufacturer Name" := MfrName(TrackingSpec."Manufacturer Code");
    end;

    procedure PopulateActivityLineMfgFromSpec(var WhseActLine: Record "Warehouse Activity Line"; TrackingSpec: Record "Tracking Specification")
    var
        WhseItemTrk: Record "Whse. Item Tracking Line";
    begin
        if TrackingSpec."Lot No." = '' then
            exit;
        WhseItemTrk.SetRange("Item No.", TrackingSpec."Item No.");
        WhseItemTrk.SetRange("Location Code", TrackingSpec."Location Code");
        WhseItemTrk.SetRange("Lot No.", TrackingSpec."Lot No.");
        if TrackingSpec."Variant Code" <> '' then
            WhseItemTrk.SetRange("Variant Code", TrackingSpec."Variant Code");
        WhseItemTrk.SetFilter("Manufacturer Code", '<>%1', '');
        if WhseItemTrk.FindFirst() then begin
            WhseActLine."Manufacturer Code" := WhseItemTrk."Manufacturer Code";
            WhseActLine."Manufacturer Name" := MfrName(WhseActLine."Manufacturer Code");
            exit;
        end;
        // Whse. Item Tracking Lines are purged after put-away registration.
        // Fall back to the Warehouse Entry which retains the code permanently.
        WhseActLine."Manufacturer Code" :=
            LookupManufacturerCodeByLot(TrackingSpec."Item No.", TrackingSpec."Variant Code", TrackingSpec."Lot No.");
        if WhseActLine."Manufacturer Code" = '' then
            WhseActLine."Manufacturer Code" :=
                LookupManufacturerCodeFromILE(TrackingSpec."Item No.", TrackingSpec."Variant Code", TrackingSpec."Lot No.");
        WhseActLine."Manufacturer Name" := MfrName(WhseActLine."Manufacturer Code");
    end;

    // Resolve the (global) Manufacturer Name for a code via the base Manufacturer
    // table (5720), mirroring the helper in Kam Reservation Subscribers.
    local procedure MfrName(MfrCode: Code[100]): Text[100]
    var
        TaskletCodeunits: Codeunit Tasklet_Codeunits;
    begin
        exit(CopyStr(TaskletCodeunits.GetManufacturerName(MfrCode), 1, 100));
    end;

    procedure LookupManufacturerCodeByLot(ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]): Code[10]
    var
        WhseEntry: Record "Warehouse Entry";
    begin
        if (ItemNo = '') or (LotNo = '') then
            exit('');

        WhseEntry.SetCurrentKey("Item No.", "Bin Code", "Location Code", "Variant Code", "Unit of Measure Code", "Lot No.");
        WhseEntry.SetRange("Item No.", ItemNo);
        WhseEntry.SetRange("Variant Code", VariantCode);
        WhseEntry.SetRange("Lot No.", LotNo);
        WhseEntry.SetFilter("Manufacturer Code", '<>%1', '');
        if WhseEntry.FindLast() then
            exit(WhseEntry."Manufacturer Code");
        exit('');
    end;

    // Secondary fallback: look up Manufacturer Code from existing Item Ledger Entries
    // for the same item and lot. Covers stock received before the Warehouse Entry lookup
    // was in place, or locations without bin tracking.
    procedure LookupManufacturerCodeFromILE(ItemNo: Code[20]; VariantCode: Code[10]; LotNo: Code[50]): Code[10]
    var
        ILE: Record "Item Ledger Entry";
    begin
        if (ItemNo = '') or (LotNo = '') then
            exit('');
        ILE.SetRange("Item No.", ItemNo);
        ILE.SetRange("Variant Code", VariantCode);
        ILE.SetRange("Lot No.", LotNo);
        ILE.SetFilter("Manufacturer Code", '<>%1', '');
        if ILE.FindLast() then
            exit(ILE."Manufacturer Code");
        exit('');
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeSetTransferAsDirect(var TransHeader: Record "Transfer Header"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCreateLotReservationForTransferLine(var TransLine: Record "Transfer Line"; var ReqLine: Record "Requisition Line"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateLotReservationForTransferLine(var TransLine: Record "Transfer Line"; var ReqLine: Record "Requisition Line")
    begin
    end;
}
