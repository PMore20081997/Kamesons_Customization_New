// codeunit 99977 "Multiple Inve Pick"
// {
//     SingleInstance = true;
//     trigger OnRun()
//     begin

//     end;

//     var
//         myInt: Integer;
//         G_CallFromCheckSourceDoc: Boolean;


//     //Step1++
//     procedure CallFromCheckSourceDoc(_CallFromCheckSourceDoc: Boolean)
//     begin
//         Clear(G_CallFromCheckSourceDoc);
//         G_CallFromCheckSourceDoc := _CallFromCheckSourceDoc;
//     end;

//     //Step2++
//     //This is called from Two area
//     // 1. In the "Create Invt. Pick" report where system checking the lines are exist or not. (This time WarehouseActivityHeader."Location Code" = '')
//     // 2. Before calling Create Pick Function to filter the line.
//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Inventory Pick/Movement", 'OnBeforeFindSalesLine', '', false, false)]
//     // local procedure OnBeforeFindSalesLine(var SalesLine: Record "Sales Line"; WarehouseActivityHeader: Record "Warehouse Activity Header")
//     // begin
//     //     //SalesLine.CalcFields("Item Is Blocked", "Item Is OPS Blocked", "Item Is Sales Blocked");
//     //     if G_CallFromCheckSourceDoc = false then begin
//     //         if (WarehouseActivityHeader."Location Code" <> '') AND (WarehouseActivityHeader.Type = WarehouseActivityHeader.Type::"Invt. Pick") then begin
//     //             SalesLine.SetRange("Whs. Class Code type", WarehouseActivityHeader."Whs. Class Code type");
//     //             SalesLine.SetFilter("Unable to Pick", '%1', '');
//     //             // SalesLine.SetRange("Item Is Blocked", false);
//     //             // SalesLine.SetRange("Item Is Sales Blocked", false);
//     //             // SalesLine.SetRange("Item Is OPS Blocked", false);
//     //         end;
//     //     end;
//     //     Clear(G_CallFromCheckSourceDoc);
//     // end;




//     //Manage Bin Content Sorting for Pick Qty Descending
//     [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Inventory Pick/Movement", 'OnBeforeFindFromBinContent', '', true, true)]
//     local procedure OnBeforeFindFromBinContent_Custom(
// var FromBinContent: Record "Bin Content";
//         var WarehouseActivityLine: Record "Warehouse Activity Line";
//         FromBinCode: Code[20];
//         BinCode: Code[20];
//         IsInvtMovement: Boolean;
//         IsBlankInvtMovement: Boolean;
//         DefaultBin: Boolean;
//         WhseItemTrackingSetup: Record "Item Tracking Setup";
//         var WarehouseActivityHeader: Record "Warehouse Activity Header";
//         var WarehouseRequest: Record "Warehouse Request")
//     var
//         TempBinContent: Record "Bin Content" temporary;
//         QtyToPick: Decimal;
//         L_Location: Record Location;
//     begin
//         if (WarehouseActivityLine."Activity Type" = WarehouseActivityLine."Activity Type"::"Invt. Pick") AND (WarehouseActivityLine."Source Document" = WarehouseActivityLine."Source Document"::"Sales Order") then begin
//             L_Location.Reset();
//             L_Location.Get(WarehouseActivityLine."Location Code");
//             if L_Location.FindFirst() then begin
//                 if L_Location."Sort by Quantity" = true then begin
//                     Clear(FromBinContent);
//                     FromBinContent.Reset();
//                     FromBinContent.SetRange("Location Code", WarehouseActivityLine."Location Code");
//                     FromBinContent.SetRange("Item No.", WarehouseActivityLine."Item No.");
//                     FromBinContent.SetRange("Variant Code", WarehouseActivityLine."Variant Code");
//                     FromBinContent.SetFilter("Quantity (Base)", '>%1', 0);
//                     if FromBinContent.FindSet() then begin
//                         repeat
//                             FromBinContent."Qty For Pick Sorting" := FromBinContent.CalcQtyAvailToTakeUOM();
//                             FromBinContent.Modify();
//                         until FromBinContent.Next() = 0;
//                     end;

//                     FromBinContent.SetCurrentKey("Qty For Pick Sorting");
//                     FromBinContent.Ascending(true);
//                 end;
//             end;
//         end;
//     end;

// }