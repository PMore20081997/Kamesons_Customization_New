// codeunit 99982 "Event Subscribers DPP"
// {
//     SingleInstance = true;

//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Put-away", OnBeforeWhseActivLineInsert, '', false, false)]
//     local procedure OnBeforeWhseActivLineInsert(var WarehouseActivityLine: Record "Warehouse Activity Line")
//     var
//         L_Item: Record Item;
//         L_Zone: Record Zone;
//     begin
//         if (WarehouseActivityLine."Activity Type" <> WarehouseActivityLine."Activity Type"::"Put-away") OR (WarehouseActivityLine."Action Type" <> WarehouseActivityLine."Action Type"::Place) then
//             exit;

//         L_Item.SetLoadFields(BULK);
//         if not L_Item.Get(WarehouseActivityLine."Item No.") then
//             exit;

//         IF L_Item.BULK = true then begin
//             AssignBinZone(WarehouseActivityLine, true);
//         end
//         else begin
//             AssignBinZone(WarehouseActivityLine, false);
//         end;
//     end;

//     local procedure AssignBinZone(var P_WarehouseActivityLine: Record "Warehouse Activity Line"; IsBulk: Boolean)
//     var
//         L_BinContent: Record "Bin Content";
//         L_Zone: Record Zone;
//     begin
//         L_Zone.Reset();
//         L_Zone.SetRange("Location Code", P_WarehouseActivityLine."Location Code");
//         if IsBulk then
//             L_Zone.SetFilter(BULK, '%1', true)
//         else
//             L_Zone.SetFilter(HighBay, '%1', true);
//         if not L_Zone.FindFirst() then
//             exit;

//         L_BinContent.Reset();
//         L_BinContent.SetFilter("Location Code", '%1', P_WarehouseActivityLine."Location Code");
//         L_BinContent.SetFilter("Zone Code", '%1', L_Zone.Code);
//         L_BinContent.SetRange("Item No.", P_WarehouseActivityLine."Item No.");
//         if L_BinContent.FindFirst() then begin

//             P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
//             P_WarehouseActivityLine.Validate("Bin Code", L_BinContent."Bin Code");

//             // P_WarehouseActivityLine."Zone Code" := L_Zone.Code;
//             // P_WarehouseActivityLine."Bin Code" := L_BinContent."Bin Code";
//         end else begin
//             //Temporary++
//             L_BinContent.Reset();
//             L_BinContent.SetFilter("Location Code", '%1', P_WarehouseActivityLine."Location Code");
//             L_BinContent.SetFilter("Zone Code", '%1', L_Zone.Code);
//             L_BinContent.SetRange("Item No.", P_WarehouseActivityLine."Item No.");
//             L_BinContent.SetFilter(Fixed, '%1', true);
//             if L_BinContent.FindFirst() then begin
//                 // P_WarehouseActivityLine."Zone Code" := L_BinContent."Zone Code";
//                 // P_WarehouseActivityLine."Bin Code" := L_BinContent."Bin Code";
//                 P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
//                 P_WarehouseActivityLine.Validate("Bin Code", L_BinContent."Bin Code");
//                 //Temporary--
//             end else
//                 P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
//         end;
//     end;



//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Post Receipt", OnCreatePutAwayDocOnBeforeCreatePutAwayRun, '', false, false)]
//     local procedure OnCreatePutAwayDocOnBeforeCreatePutAwayRun()
//     begin
//         Clear(G_IsExecuting);
//         G_IsExecuting := true;
//     end;

//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterInsertEvent, '', false, false)]
//     local procedure OnAfterInsertEventWAL(var Rec: Record "Warehouse Activity Line")
//     var

//         L_BinContent: Record "Bin Content";
//         L_WhseActivLine: Record "Warehouse Activity Line";
//     begin
//         if not G_IsExecuting then
//             exit;

//         if (Rec."Activity Type" <> Rec."Activity Type"::"Put-away") OR (Rec."Action Type" <> Rec."Action Type"::Place) then
//             exit;

//         L_BinContent.Reset();
//         L_BinContent.SetFilter("Location Code", '%1', Rec."Location Code");
//         L_BinContent.SetFilter("Zone Code", '%1', Rec."Zone Code");
//         L_BinContent.SetFilter("Bin Code", '%1', Rec."Bin Code");
//         L_BinContent.SetRange("Item No.", Rec."Item No.");
//         if L_BinContent.FindFirst() then begin
//             L_BinContent.CalcFields(Quantity);

//             if L_BinContent."Max. Qty." > 0 then begin
//                 Clear(G_RemainingQty);
//                 Clear(G_SplitQtyToHandle);
//                 if (L_BinContent.Quantity + Rec.Quantity) <= L_BinContent."Max. Qty." then
//                     G_RemainingQty := 0
//                 else
//                     G_RemainingQty := (L_BinContent.Quantity + Rec.Quantity) - L_BinContent."Max. Qty.";

//                 If G_RemainingQty > 0 then begin
//                     G_SplitQtyToHandle := Rec.Quantity - ((L_BinContent.Quantity + Rec.Quantity) - L_BinContent."Max. Qty.");

//                     //if G_SplitQtyToHandle > 0 then begin
//                     Rec.Validate("Qty. to Handle", G_SplitQtyToHandle);
//                     Rec.Modify();

//                     G_IsExecuting := false;

//                     L_WhseActivLine.Copy(Rec);
//                     G_LineSpacing := true;

//                     Rec.SplitLine(L_WhseActivLine);
//                     Rec.Copy(L_WhseActivLine);

//                     G_LineSpacing := false;
//                 end;
//             end;
//         end;

//     end;

//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnBeforeInsertNewWhseActivLine, '', false, false)]
//     local procedure OnBeforeInsertNewWhseActivLine(var NewWarehouseActivityLine: Record "Warehouse Activity Line")
//     begin
//         AssignBinZone(NewWarehouseActivityLine, false);
//     end;

//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnSplitLineOnBeforeRenumberAllLines, '', false, false)]
//     local procedure OnSplitLineOnBeforeRenumberAllLines(var LineSpacing: Integer)
//     begin
//         if G_LineSpacing then
//             LineSpacing := 5000;
//     end;


//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Put-away", OnFindBin, '', false, false)]
//     local procedure OnFindBin(var BinFound: Boolean; var IsHandled: Boolean; PutAwayTemplateLine: Record "Put-away Template Line")
//     begin
//         if PutAwayTemplateLine."Put-away Template Code" = 'NO USE' then begin
//             IsHandled := true;
//             BinFound := false;
//         end;
//     end;

//     var
//         G_RemainingQty: Decimal;
//         G_SplitQtyToHandle: Decimal;
//         G_IsExecuting: Boolean;
//         G_LineSpacing: Boolean;
// }
