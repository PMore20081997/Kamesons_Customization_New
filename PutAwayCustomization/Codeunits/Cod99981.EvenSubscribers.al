// codeunit 99981 "Even Subscribers"
// {
//     SingleInstance = true;

//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Put-away", OnBeforeWhseActivLineInsert, '', false, false)]
//     local procedure OnBeforeWhseActivLineInsert(var WarehouseActivityLine: Record "Warehouse Activity Line")
//     var
//         L_Item: Record Item;
//         L_Zone: Record Zone;
//     begin
//         if not ((WarehouseActivityLine."Activity Type" = WarehouseActivityLine."Activity Type"::"Put-away") OR (WarehouseActivityLine."Action Type" = WarehouseActivityLine."Action Type"::Place)) then
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

//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Post Receipt", OnAfterCreatePutAwayDoc, '', false, false)]
//     local procedure OnAfterCreatePutAwayDoc(var WhseActivHeader: Record "Warehouse Activity Header")
//     var
//         L_WarehouseActivityLineTake: Record "Warehouse Activity Line";
//         L_WarehouseActivityLinePlace: Record "Warehouse Activity Line";
//         L_BinContent: Record "Bin Content";
//         L_Zone: Record Zone;
//         L_WhseActivLine: Record "Warehouse Activity Line";
//     begin
//         L_WarehouseActivityLineTake.Reset();
//         L_WarehouseActivityLineTake.SetRange("Activity Type", L_WarehouseActivityLineTake."Activity Type"::"Put-away");
//         L_WarehouseActivityLineTake.SetRange("No.", WhseActivHeader."No.");
//         L_WarehouseActivityLineTake.SetFilter("Action Type", '%1', L_WarehouseActivityLineTake."Action Type"::Take);
//         if L_WarehouseActivityLineTake.FindSet() then begin
//             repeat
//                 L_WarehouseActivityLinePlace.Reset();
//                 L_WarehouseActivityLinePlace.SetRange("Activity Type", L_WarehouseActivityLineTake."Activity Type");
//                 L_WarehouseActivityLinePlace.SetRange("No.", WhseActivHeader."No.");
//                 L_WarehouseActivityLinePlace.SetRange("Action Type", L_WarehouseActivityLinePlace."Action Type"::Place);
//                 L_WarehouseActivityLinePlace.SetFilter("Line No.", '>%1', L_WarehouseActivityLineTake."Line No.");
//                 if L_WarehouseActivityLinePlace.FindFirst() then begin
//                     L_BinContent.Reset();
//                     L_BinContent.SetFilter("Location Code", '%1', L_WarehouseActivityLinePlace."Location Code");
//                     L_BinContent.SetFilter("Zone Code", '%1', L_WarehouseActivityLinePlace."Zone Code");
//                     L_BinContent.SetFilter("Bin Code", '%1', L_WarehouseActivityLinePlace."Bin Code");
//                     L_BinContent.SetRange("Item No.", L_WarehouseActivityLinePlace."Item No.");
//                     if L_BinContent.FindFirst() then begin
//                         L_BinContent.CalcFields(Quantity);
//                         If L_BinContent."Max. Qty." > 0 then begin
//                             Clear(G_RemainingQty);
//                             Clear(G_SplitQtyToHandle);
//                             if (L_BinContent.Quantity + L_WarehouseActivityLinePlace.Quantity) <= L_BinContent."Max. Qty." then
//                                 G_RemainingQty := 0
//                             else
//                                 G_RemainingQty := (L_BinContent.Quantity + L_WarehouseActivityLinePlace.Quantity) - L_BinContent."Max. Qty.";

//                             If G_RemainingQty > 0 then
//                                 G_SplitQtyToHandle := L_WarehouseActivityLinePlace.Quantity - ((L_BinContent.Quantity + L_WarehouseActivityLinePlace.Quantity) - L_BinContent."Max. Qty.");

//                             if G_SplitQtyToHandle > 0 then begin
//                                 L_WarehouseActivityLinePlace.Validate("Qty. to Handle", G_SplitQtyToHandle);
//                                 L_WarehouseActivityLinePlace.Modify();

//                                 L_WhseActivLine.Copy(L_WarehouseActivityLinePlace);

//                                 L_WarehouseActivityLinePlace.SplitLine(L_WhseActivLine);
//                                 L_WarehouseActivityLinePlace.Copy(L_WhseActivLine);
//                             end;

//                         end;
//                     end;
//                 end;

//             until L_WarehouseActivityLineTake.Next() = 0;
//         end;
//     end;


//     [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnBeforeInsertNewWhseActivLine, '', false, false)]
//     local procedure OnBeforeInsertNewWhseActivLine(var NewWarehouseActivityLine: Record "Warehouse Activity Line")
//     begin
//         AssignBinZone(NewWarehouseActivityLine, false);
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

//     local procedure AssignBulkBinZone(var P_WarehouseActivityLine: Record "Warehouse Activity Line")
//     var
//         L_BinContent: Record "Bin Content";
//         L_Zone: Record Zone;
//     begin

//         L_Zone.Reset();
//         L_Zone.SetRange("Location Code", P_WarehouseActivityLine."Location Code");
//         L_Zone.SetFilter(BULK, '%1', true);
//         if not L_Zone.FindFirst() then
//             exit;

//         L_BinContent.Reset();
//         L_BinContent.SetFilter("Location Code", '%1', P_WarehouseActivityLine."Location Code");
//         L_BinContent.SetFilter("Zone Code", '%1', L_Zone.Code);
//         L_BinContent.SetRange("Item No.", P_WarehouseActivityLine."Item No.");
//         if L_BinContent.FindFirst() then begin
//             P_WarehouseActivityLine."Zone Code" := L_Zone.Code;
//             P_WarehouseActivityLine."Bin Code" := L_BinContent."Bin Code";
//         end else begin
//             P_WarehouseActivityLine."Zone Code" := L_Zone.Code;
//         end;


//     end;



//     local procedure AssignHighBayBinZone(var P_WarehouseActivityLine: Record "Warehouse Activity Line")
//     var
//         L_BinContent: Record "Bin Content";
//         L_Zone: Record Zone;
//     begin
//         L_Zone.Reset();
//         L_Zone.SetRange("Location Code", P_WarehouseActivityLine."Location Code");
//         L_Zone.SetFilter(HighBay, '%1', true);
//         if not L_Zone.FindFirst() then
//             exit;

//         L_BinContent.Reset();
//         L_BinContent.SetFilter("Location Code", '%1', P_WarehouseActivityLine."Location Code");
//         L_BinContent.SetFilter("Zone Code", '%1', L_Zone.Code);
//         L_BinContent.SetRange("Item No.", P_WarehouseActivityLine."Item No.");
//         if L_BinContent.FindFirst() then begin
//             P_WarehouseActivityLine."Zone Code" := L_Zone.Code;
//             P_WarehouseActivityLine."Bin Code" := L_BinContent."Bin Code";
//         end else begin
//             P_WarehouseActivityLine.Validate("Zone Code", L_Zone.Code);
//             //P_WarehouseActivityLine."Zone Code" := L_Zone.Code;
//         end;
//     end;

//     var
//         G_RemainingQty: Decimal;
//         G_SplitQtyToHandle: Decimal;
// }