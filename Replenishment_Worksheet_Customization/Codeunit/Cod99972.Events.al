codeunit 99972 Events
{

    procedure GetMainWarehouse(): Code[20]
    var
        L_WhseSetup: Record "Warehouse Setup";
    begin
        L_WhseSetup.Get();
        exit(L_WhseSetup."MAIN Warehouse");
    end;

    procedure GetReceiveWarehouse(): Code[20]
    var
        L_WhseSetup: Record "Warehouse Setup";
    begin
        L_WhseSetup.Get();
        exit(L_WhseSetup."RECEIVE Warehouse");
    end;

    procedure GetPickBulkZone(P_LocationCode: Code[10]): Code[10]
    var
        L_Zone: Record Zone;
    begin
        L_Zone.Reset();
        L_Zone.SetRange("Location Code", P_LocationCode);
        L_Zone.SetFilter(L_Zone.BULK, '%1', true);
        if L_Zone.FindFirst() then
            exit(L_Zone.Code);
    end;

    procedure GetReceiveBulkZone(P_LocationCode: Code[10]): Code[10]
    var
        L_Zone: Record Zone;
    begin
        L_Zone.Reset();
        L_Zone.SetRange("Location Code", P_LocationCode);
        L_Zone.SetFilter(L_Zone.BULK, '%1', true);
        if L_Zone.FindFirst() then
            exit(L_Zone.Code);
    end;

    procedure GetPickHighBayZone(P_LocationCode: Code[10]): Code[10]
    var
        L_Zone: Record Zone;
    begin
        L_Zone.Reset();
        L_Zone.SetRange("Location Code", P_LocationCode);
        L_Zone.SetFilter(L_Zone.HighBay, '%1', true);
        if L_Zone.FindFirst() then
            exit(L_Zone.Code);
    end;



    // [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnAfterInsertEvent, '', false, false)]
    // local procedure MyProcedure()
    // var
    //     i: Integer;
    // begin
    //     Clear(i);
    // end;

    // local procedure CarryOutReqLineAction(var ReqLine: Record "Requisition Line")
    // var
    //     CarryOutAction: Codeunit "Carry Out Action";
    //     Failed: Boolean;
    //     IsHandled: Boolean;
    // begin
    //     case ReqLine."Replenishment System" of
    //         ReqLine."Replenishment System"::Transfer:
    //             case ReqLine."Action Message" of
    //                 ReqLine."Action Message"::New, ReqLine."Action Message"::" ":
    //                     begin
    //                         CarryOutAction.InsertTransLine(ReqLine, TransHeader);
    //                     end;
    //             end;
    //     end;
    // end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnInsertTransHeaderOnBeforeTransHeaderModify, '', false, false)]
    local procedure OnInsertTransHeaderOnBeforeTransHeaderModify(var TransHeader: Record "Transfer Header")
    begin
        TransHeader."Direct Transfer" := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnAfterInsertTransLine, '', false, false)]
    local procedure OnAfterInsertTransLine(var TransLine: Record "Transfer Line"; var ReqLine: Record "Requisition Line")
    var
        TempReservationEntry1: Record "Reservation Entry";
        ReservationStatus: Enum "Reservation Status";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
    begin
        TempReservationEntry1.Reset();
        TempReservationEntry1."Source Type" := 5741;
        TempReservationEntry1."Source Subtype" := 0;
        TempReservationEntry1."Source ID" := TransLine."Document No.";
        TempReservationEntry1."Source Ref. No." := TransLine."Line No.";
        TempReservationEntry1."Lot No." := ReqLine."Lot No.";
        TempReservationEntry1."Package No." := ReqLine."Package No.";
        if ReqLine."Lot Expiration Date" <> 0D then
            TempReservationEntry1."Expiration Date" := ReqLine."Lot Expiration Date";

        CreateReservEntry.CreateReservEntryFor(DATABASE::"Transfer Line", 0, TransLine."Document No.", '', 0, TransLine."Line No.", TransLine."Qty. per Unit of Measure", TransLine.Quantity, TransLine.Quantity, TempReservationEntry1);
        CreateReservEntry.SetDates(0D, ReqLine."Lot Expiration Date");
        CreateReservEntry.CreateEntry(TransLine."Item No.", TransLine."Variant Code", TransLine."Transfer-from Code", '', 0D, TransLine."Shipment Date", 0, ReservationStatus::Surplus);

        TempReservationEntry1.Reset();
        TempReservationEntry1."Source Type" := 5741;
        TempReservationEntry1."Source Subtype" := 1;
        TempReservationEntry1."Source ID" := TransLine."Document No.";
        TempReservationEntry1."Source Ref. No." := TransLine."Line No.";
        TempReservationEntry1."Lot No." := ReqLine."Lot No.";
        TempReservationEntry1."Package No." := ReqLine."Package No.";
        if ReqLine."Lot Expiration Date" <> 0D then
            TempReservationEntry1."Expiration Date" := ReqLine."Lot Expiration Date";

        CreateReservEntry.CreateReservEntryFor(DATABASE::"Transfer Line", 1, TransLine."Document No.", '', 0, TransLine."Line No.", TransLine."Qty. per Unit of Measure", TransLine.Quantity, TransLine.Quantity, TempReservationEntry1);
        CreateReservEntry.SetDates(0D, ReqLine."Lot Expiration Date");
        CreateReservEntry.CreateEntry(TransLine."Item No.", TransLine."Variant Code", TransLine."Transfer-to Code", '', TransLine."Receipt Date", 0D, 0, ReservationStatus::Surplus);


        TransLine.Validate("Transfer-from Bin Code", ReqLine."From Bin Code");
        TransLine.Validate("Transfer-To Bin Code", ReqLine."Bin Code");
        TransLine.Modify();
    end;

    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", OnAfterCopyTrackingFromReservEntry, '', false, false)]
    local procedure OnAfterCopyTrackingFromReservEntry(var ReservationEntry: Record "Reservation Entry"; FromReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry."Package No." := FromReservationEntry."Package No.";
    end;

    // [EventSubscriber(ObjectType::Table, Database::"Transfer Line", OnAfterModifyEvent, '', false, false)]
    // local procedure MyProcedure()
    // var
    //     i: Integer;
    // begin
    //     Clear(i);
    // end;
}
