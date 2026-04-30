// codeunit 99972 Events
// {

//     procedure GetMainWarehouse(): Code[20]
//     var
//         L_WhseSetup: Record "Warehouse Setup";
//     begin
//         L_WhseSetup.Get();
//         exit(L_WhseSetup."MAIN Warehouse");
//     end;

//     procedure GetReceiveWarehouse(): Code[20]
//     var
//         L_WhseSetup: Record "Warehouse Setup";
//     begin
//         L_WhseSetup.Get();
//         exit(L_WhseSetup."RECEIVE Warehouse");
//     end;

//     procedure GetBulkZone(P_LocationCode: Code[10]): Code[10]
//     var
//         L_Zone: Record Zone;
//     begin
//         L_Zone.Reset();
//         L_Zone.SetRange("Location Code", P_LocationCode);
//         L_Zone.SetFilter(L_Zone.BULK, '%1', true);
//         if L_Zone.FindFirst() then
//             exit(L_Zone.Code);
//     end;

//     // procedure GetReceiveBulkZone(P_LocationCode: Code[10]): Code[10]
//     // begin
//     //     exit(GetPickBulkZone(P_LocationCode));
//     // end;

//     procedure GetHighBayZone(P_LocationCode: Code[10]): Code[10]
//     var
//         L_Zone: Record Zone;
//     begin
//         L_Zone.Reset();
//         L_Zone.SetRange("Location Code", P_LocationCode);
//         L_Zone.SetFilter(L_Zone.HighBay, '%1', true);
//         if L_Zone.FindFirst() then
//             exit(L_Zone.Code);
//     end;

//     procedure GetGenDecantZone(P_LocationCode: Code[10]): Code[10]
//     var
//         L_Zone: Record Zone;
//     begin
//         L_Zone.Reset();
//         L_Zone.SetRange("Location Code", P_LocationCode);
//         L_Zone.SetFilter(L_Zone."General", '%1', true);
//         if L_Zone.FindFirst() then
//             exit(L_Zone.Code);
//     end;

//     procedure GetGenDecantZonefromBinContent(P_LocationCode: Code[10]; _ItemNo: Code[20]): Code[10]
//     var
//         L_BinContent: Record "Bin Content";
//     begin
//         // L_Zone.Reset();
//         // L_Zone.SetRange("Location Code", P_LocationCode);
//         // L_Zone.SetFilter(L_Zone."General", '%1', true);
//         // if L_Zone.FindFirst() then
//         //     exit(L_Zone.Code);

//         L_BinContent.Reset();
//         L_BinContent.SetRange("Location Code", P_LocationCode);
//         L_BinContent.SetRange("Item No.", _ItemNo);
//         if L_BinContent.FindFirst() then begin
//             exit(L_BinContent."Zone Code")
//         end;
//     end;



//     // [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnAfterInsertEvent, '', false, false)]
//     // local procedure MyProcedure()
//     // var
//     //     i: Integer;
//     // begin
//     //     Clear(i);
//     // end;

//     // local procedure CarryOutReqLineAction(var ReqLine: Record "Requisition Line")
//     // var
//     //     CarryOutAction: Codeunit "Carry Out Action";
//     //     Failed: Boolean;
//     //     IsHandled: Boolean;
//     // begin
//     //     case ReqLine."Replenishment System" of
//     //         ReqLine."Replenishment System"::Transfer:
//     //             case ReqLine."Action Message" of
//     //                 ReqLine."Action Message"::New, ReqLine."Action Message"::" ":
//     //                     begin
//     //                         CarryOutAction.InsertTransLine(ReqLine, TransHeader);
//     //                     end;
//     //             end;
//     //     end;
//     // end;

//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnInsertTransHeaderOnBeforeTransHeaderModify, '', false, false)]
//     local procedure OnInsertTransHeaderOnBeforeTransHeaderModify(var TransHeader: Record "Transfer Header")
//     begin
//         TransHeader."Direct Transfer" := true;
//     end;

//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Carry Out Action", OnAfterInsertTransLine, '', false, false)]
//     local procedure OnAfterInsertTransLine(var TransLine: Record "Transfer Line"; var ReqLine: Record "Requisition Line")
//     var
//         TempReservationEntry1: Record "Reservation Entry";
//         ReservationStatus: Enum "Reservation Status";
//         CreateReservEntry: Codeunit "Create Reserv. Entry";
//     begin
//         TempReservationEntry1.Reset();
//         TempReservationEntry1."Source Type" := 5741;
//         TempReservationEntry1."Source Subtype" := 0;
//         TempReservationEntry1."Source ID" := TransLine."Document No.";
//         TempReservationEntry1."Source Ref. No." := TransLine."Line No.";
//         TempReservationEntry1."Lot No." := ReqLine."Lot No.";
//         TempReservationEntry1."Package No." := ReqLine."Package No.";
//         TempReservationEntry1."Manufacturer Code" := ReqLine."Manufacturer Code";
//         if ReqLine."Lot Expiration Date" <> 0D then
//             TempReservationEntry1."Expiration Date" := ReqLine."Lot Expiration Date";

//         CreateReservEntry.CreateReservEntryFor(DATABASE::"Transfer Line", 0, TransLine."Document No.", '', 0, TransLine."Line No.", TransLine."Qty. per Unit of Measure", TransLine.Quantity, TransLine.Quantity, TempReservationEntry1);
//         CreateReservEntry.SetDates(0D, ReqLine."Lot Expiration Date");
//         CreateReservEntry.CreateEntry(TransLine."Item No.", TransLine."Variant Code", TransLine."Transfer-from Code", '', 0D, TransLine."Shipment Date", 0, ReservationStatus::Surplus);

//         TempReservationEntry1.Reset();
//         TempReservationEntry1."Source Type" := 5741;
//         TempReservationEntry1."Source Subtype" := 1;
//         TempReservationEntry1."Source ID" := TransLine."Document No.";
//         TempReservationEntry1."Source Ref. No." := TransLine."Line No.";
//         TempReservationEntry1."Lot No." := ReqLine."Lot No.";
//         TempReservationEntry1."Package No." := ReqLine."Package No.";
//         TempReservationEntry1."Manufacturer Code" := ReqLine."Manufacturer Code";
//         if ReqLine."Lot Expiration Date" <> 0D then
//             TempReservationEntry1."Expiration Date" := ReqLine."Lot Expiration Date";

//         CreateReservEntry.CreateReservEntryFor(DATABASE::"Transfer Line", 1, TransLine."Document No.", '', 0, TransLine."Line No.", TransLine."Qty. per Unit of Measure", TransLine.Quantity, TransLine.Quantity, TempReservationEntry1);
//         CreateReservEntry.SetDates(0D, ReqLine."Lot Expiration Date");
//         CreateReservEntry.CreateEntry(TransLine."Item No.", TransLine."Variant Code", TransLine."Transfer-to Code", '', TransLine."Receipt Date", 0D, 0, ReservationStatus::Surplus);


//         TransLine.Validate("Transfer-from Bin Code", ReqLine."From Bin Code");
//         TransLine.Validate("Transfer-To Bin Code", ReqLine."Bin Code");
//         TransLine.Modify();
//     end;

//     [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", OnAfterCopyTrackingFromReservEntry, '', false, false)]
//     local procedure OnAfterCopyTrackingFromReservEntry(var ReservationEntry: Record "Reservation Entry"; FromReservationEntry: Record "Reservation Entry")
//     begin
//         ReservationEntry."Package No." := FromReservationEntry."Package No.";
//         ReservationEntry."Manufacturer Code" := FromReservationEntry."Manufacturer Code";
//     end;

//     [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", OnBeforeAddToGlobalRecordSet, '', false, false)]
//     local procedure ItemTrackingLines_OnBeforeAddToGlobalRecordSet(var TrackingSpecification: Record "Tracking Specification"; EntriesExist: Boolean; CurrentSignFactor: Integer; var TempTrackingSpecification: Record "Tracking Specification" temporary)
//     begin
//         if TrackingSpecification."Manufacturer Code" <> '' then
//             exit;
//         if TempTrackingSpecification."Manufacturer Code" <> '' then begin
//             TrackingSpecification."Manufacturer Code" := TempTrackingSpecification."Manufacturer Code";
//             exit;
//         end;
//         TrackingSpecification."Manufacturer Code" :=
//             LookupManufacturerCodeByLot(TrackingSpecification."Item No.", TrackingSpecification."Variant Code", TrackingSpecification."Lot No.");
//     end;

//     procedure LookupManufacturerCodeByLot(P_ItemNo: Code[20]; P_VariantCode: Code[10]; P_LotNo: Code[50]): Code[100]
//     var
//         L_WhseEntry: Record "Warehouse Entry";
//     begin
//         if (P_ItemNo = '') or (P_LotNo = '') then
//             exit('');

//         L_WhseEntry.SetCurrentKey("Item No.", "Bin Code", "Location Code", "Variant Code", "Unit of Measure Code", "Lot No.", "Serial No.", "Entry Type");
//         L_WhseEntry.SetRange("Item No.", P_ItemNo);
//         L_WhseEntry.SetRange("Variant Code", P_VariantCode);
//         L_WhseEntry.SetRange("Lot No.", P_LotNo);
//         L_WhseEntry.SetFilter("Manufacturer Code", '<>%1', '');
//         if L_WhseEntry.FindLast() then
//             exit(L_WhseEntry."Manufacturer Code");
//         exit('');
//     end;

//     procedure GetBinContent(_LocationCode: Code[20]; _ZoneCode: Code[10]; _ItemNo: Code[20]) RetBinContent: Record "Bin Content"
//     begin
//         RetBinContent.SetRange("Location Code", _LocationCode);
//         RetBinContent.SetRange("Zone Code", _ZoneCode);
//         RetBinContent.SetRange("Item No.", _ItemNo);
//         if RetBinContent.FindFirst() then;
//     end;



//     // Hop 1a: Whse. Item Tracking Line -> Warehouse Activity Line
//     //  (fires for pick flows that call WhseActLine.CopyTrackingFromWhseItemTrackingLine)
//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromWhseItemTrackingLine, '', false, false)]
//     local procedure OnAfterCopyTrkgFromWhseItemTrkgLineToWhseActLine(var WarehouseActivityLine: Record "Warehouse Activity Line"; WhseItemTrackingLine: Record "Whse. Item Tracking Line")
//     begin
//         WarehouseActivityLine."Manufacturer Code" := WhseItemTrackingLine."Manufacture Code";
//     end;

//     // Hop 1b: Tracking Specification -> Warehouse Activity Line
//     //  Inventory Movement from Movement Worksheet assigns tracking via CopyTrackingFromSpec.
//     //  Tracking Specification has no Manufacture Code, so look it up from Whse. Item Tracking Line by Item + Lot.
//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromSpec, '', false, false)]
//     local procedure OnAfterCopyTrkgFromSpecToWhseActLine(var WarehouseActivityLine: Record "Warehouse Activity Line"; TrackingSpecification: Record "Tracking Specification")
//     var
//         WhseItemTrkLine: Record "Whse. Item Tracking Line";
//     begin
//         if TrackingSpecification."Lot No." = '' then
//             exit;
//         WhseItemTrkLine.SetRange("Item No.", TrackingSpecification."Item No.");
//         WhseItemTrkLine.SetRange("Location Code", TrackingSpecification."Location Code");
//         WhseItemTrkLine.SetRange("Lot No.", TrackingSpecification."Lot No.");
//         if TrackingSpecification."Variant Code" <> '' then
//             WhseItemTrkLine.SetRange("Variant Code", TrackingSpecification."Variant Code");
//         WhseItemTrkLine.SetFilter("Manufacture Code", '<>%1', '');
//         if WhseItemTrkLine.FindFirst() then
//             WarehouseActivityLine."Manufacturer Code" := WhseItemTrkLine."Manufacture Code";
//     end;

//     // Hop 2: Warehouse Activity Line -> Warehouse Journal Line
//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Journal Line", OnAfterCopyTrackingFromWhseActivityLine, '', false, false)]
//     local procedure OnAfterCopyTrkgFromWhseActLineToWhseJnlLine(var WarehouseJournalLine: Record "Warehouse Journal Line"; WarehouseActivityLine: Record "Warehouse Activity Line")
//     begin
//         WarehouseJournalLine."Manufacturer Code" := WarehouseActivityLine."Manufacturer Code";
//     end;

//     // Hop 3a: Warehouse Journal Line -> Warehouse Entry (take/negative side)
//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnAfterCopyTrackingFromWhseJnlLine, '', false, false)]
//     local procedure OnAfterCopyTrkgFromWhseJnlLineToWhseEntry(var WarehouseEntry: Record "Warehouse Entry"; WarehouseJournalLine: Record "Warehouse Journal Line")
//     begin
//         WarehouseEntry."Manufacturer Code" := WarehouseJournalLine."Manufacturer Code";
//     end;

//     // Hop 3b: Warehouse Journal Line -> Warehouse Entry (place/positive side for movements)
//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Entry", OnAfterCopyTrackingFromNewWhseJnlLine, '', false, false)]
//     local procedure OnAfterCopyTrkgFromNewWhseJnlLineToWhseEntry(var WarehouseEntry: Record "Warehouse Entry"; WarehouseJournalLine: Record "Warehouse Journal Line")
//     begin
//         WarehouseEntry."Manufacturer Code" := WarehouseJournalLine."Manufacturer Code";
//     end;
// }


