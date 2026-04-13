namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Worksheet;

codeunit 99973 SingleInstanceCU
{
    SingleInstance = true;

    //New++ 10042026++
    [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeNeedToReplenish, '', false, false)]
    local procedure OnBeforeNeedToReplenish(var BinContent: Record "Bin Content"; var IsHandled: Boolean; var Result: Boolean)
    begin
        If BinContent.CalcQtyAvailToTake(0) = 0 then begin
            IsHandled := true;
            Result := true;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::Replenishment, OnBeforeFindReplenishmtBin, '', false, false)]
    local procedure OnBeforeFindReplenishmtBin(RemainQtyToReplenishBase: Decimal)
    begin
        Clear(G_RemainQtyToReplenishBase);
        G_RemainQtyToReplenishBase := RemainQtyToReplenishBase;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::Replenishment, OnFindReplenishmtBinOnAfterFromBinContentSetFilters, '', false, false)]
    local procedure OnFindReplenishmtBinOnAfterFromBinContentSetFilters(var FromBinContent: Record "Bin Content"; var ToBinContent: Record "Bin Content")
    begin

        Clear(G_ItemNo);
        G_ItemNo := ToBinContent."Item No.";

        Clear(ToBinContent);
        ToBinContent.Reset();
        ToBinContent.SetRange("Item No.", G_ItemNo);
        ToBinContent.SetRange("Location Code", G_Events.GetReceiveWarehouse());
        ToBinContent.SetRange("Zone Code", G_Events.GetPickBulkZone(G_Events.GetReceiveWarehouse()));
        ToBinContent.SetRange("Bin Code", 'BULK DECANT');
        if ToBinContent.FindFirst() then;

        // begin
        //     if ToBinContent.CalcQtyAvailToTake(0) >= RemainQtyToReplenishBase then
        //         exit;
        // end;

        FromBinContent.Reset();
        FromBinContent.SetRange("Item No.", G_ItemNo);
        FromBinContent.SetRange("Location Code", G_Events.GetReceiveWarehouse());
        FromBinContent.SetRange("Zone Code", G_Events.GetPickHighBayZone(G_Events.GetReceiveWarehouse()));
        FromBinContent.SetRange("Bin Code", 'HIGHBAY');
        if FromBinContent.FindFirst() then;

        Clear(G_ItemNo);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Whse. Worksheet Line", OnAfterValidateEvent, "Variant Code", false, false)]
    local procedure OnAfterValidateEventVariantCode(var Rec: Record "Whse. Worksheet Line")
    begin
        if Rec.IsTemporary then begin
            Rec."Location Code" := G_Events.GetReceiveWarehouse();
        end;
    end;

    procedure ExecutedFromCustomMovementWorksheet(P_Flag: Boolean)
    var
        myInt: Integer;
    begin
        Clear(ExecutedFromCustomMovement);
        ExecutedFromCustomMovement := P_Flag;
    end;
    //New-- 10042026--

    var
        G_ItemNo: Code[20];
        G_Events: Codeunit Events;
        ExecutedFromCustomMovement: Boolean;
        G_RemainQtyToReplenishBase: Decimal;
}
