namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using System.Utilities;
using Microsoft.Inventory.Transfer;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Explains Bulk Replenishment in plain English for page 99941.
///
/// MIRRORS report 99971 "Cal _Bin Replenishment New".FindEmptyTotesAndCreate-
/// RepWorksheet. The report is ProcessingOnly and writes worksheet lines, so
/// it cannot be run for a diagnostic - this codeunit re-walks the same checks
/// read-only.
///
/// The question users actually ask here is "why did my item NOT appear on the
/// worksheet", and a missing line has nothing to click on. So every silent
/// exit / skip in the report is given a reportable reason:
///
///   1. Item routing type is not BULK            (report OnPreDataItem filter)
///   2. No Bulk-flagged Bin Content in Main WH    (report early exit)
///   3. Bin is above its Min Qty                  (the trigger condition)
///   4. Open Transfer Orders already close the gap (TO netting)
///   5. No usable FEFO source in the Receive BULK bin
///   6. A worksheet line already exists for the stock (duplicate guard)
///
/// When the report changes, update this codeunit and enum 99943 together.
/// </summary>
codeunit 99945 "Bulk Replen Explainer NDPP"
{
    Access = Public;
    Permissions = tabledata "Bin Content" = r,
                  tabledata Bin = r,
                  tabledata Item = r,
                  tabledata "Warehouse Entry" = r,
                  tabledata "Transfer Line" = r,
                  tabledata "Decant Details" = r;

    var
        G_Facts: Codeunit "Routing Explainer Facts NDPP";
        NotBulkTxt: Label 'Item %1 has a routing type of %2, not BULK. Bulk Replenishment only ever considers BULK items, so this item will never appear on the replenishment worksheet. It is replenished through the decant process instead.', Comment = '%1 = Item No.; %2 = routing type';
        NoBulkBinTxt: Label 'Item %1 has no Bulk-flagged bin set up in %2. Bulk Replenishment cannot work out where to send stock, so the item is skipped. Ask your supervisor to set up the BULK bin content for this item.', Comment = '%1 = Item No.; %2 = Main location';
        AboveMinTxt: Label 'Bin %1 is not below its minimum, so no replenishment is needed:%2%2   On hand           %3%2   Minimum quantity  %4%2%2Replenishment is only created when the on-hand quantity falls to or below the minimum.', Comment = '%1 = bin; %2 = newline; %3 = on hand; %4 = min qty';
        CoveredByTOTxt: Label 'Bin %1 is below its minimum, but stock is already on its way:%2%2   On hand                %3%2   On open Transfer Order %4%2   Effective total        %5%2   Minimum quantity       %6%2%2Because the Transfer Orders already close the gap, no new replenishment line is created. It would duplicate stock that is in transit.', Comment = '%1 = bin; %2 = newline; %3 = on hand; %4 = TO qty; %5 = total; %6 = min';
        NoSourceTxt: Label 'Bin %1 is below its minimum and needs %2, but there is no usable stock in the Receive BULK bin %3.%4%4Source stock must have all of: quantity above zero, an expiry date on or after today, and a manufacturer code. Stock missing a manufacturer code is skipped, which is the most common cause.', Comment = '%1 = bin; %2 = qty needed; %3 = receive bin; %4 = newline';
        AlreadyOnWkshTxt: Label 'Bin %1 needs %2, and source stock exists - but the worksheet already holds a line for this item from the same source. The duplicate guard stops a second line being created for stock that is already planned. Check the existing worksheet lines before recalculating.', Comment = '%1 = bin; %2 = qty needed';
        WouldReplenishTxt: Label 'Bin %1 is below its minimum and replenishment WOULD be created:%2%2   On hand            %3%2   Minimum quantity   %4%2   Maximum quantity   %5%2   Quantity to top up %6%2%2Source stock is taken from the Receive BULK bin %7 in expiry-date order (oldest first). If no line appeared, the worksheet may not have been recalculated since the stock levels changed.', Comment = '%1 = bin; %2 = newline; %3 = on hand; %4 = min; %5 = max; %6 = qty; %7 = receive bin';
        OutcomeNoLineTxt: Label 'No replenishment line would be created for this item.';
        OutcomeWouldCreateTxt: Label 'A replenishment line WOULD be created for %1.', Comment = '%1 = qty';
        MainBinRoleTxt: Label 'Main WH BULK bin';
        ReceiveBinRoleTxt: Label 'Receive BULK bin';

    /// <summary>
    /// Fills the buffer with the Bulk Replenishment explanation for one item.
    /// </summary>
    procedure Explain(var Buffer: Record "Routing Explanation NDPP" temporary; Item: Record Item; BinCodeFilter: Code[20])
    var
        BinContent: Record "Bin Content";
        MainLocation: Code[20];
        ReceiveLocation: Code[20];
        ReceiveBulkBin: Code[20];
        MainBulkBin: Code[20];
        OnHand: Decimal;
        MinBaseQty: Decimal;
        MaxBaseQty: Decimal;
        QtyPerUoM: Decimal;
        TransferQty: Decimal;
        EffectiveQty: Decimal;
        QtyToReplenish: Decimal;
        SourceQty: Decimal;
        DecantEntryType: Option Decant,Replenishment;
    begin
        MainLocation := G_Facts.GetMainLocation();
        ReceiveLocation := G_Facts.GetReceiveLocation();
        ReceiveBulkBin := G_Facts.FindFlaggedBin(ReceiveLocation, "Item Routing Type NDPP"::BULK, false);

        // Worksheet history for this item - shown whatever the verdict, so a
        // user told "no line was created" can see the lines that DO exist.
        G_Facts.AddRecentDecantActivity(Buffer, Item."No.", DecantEntryType::Replenishment, 10);

        // ---- Rule 1: the report filters the dataitem to BULK items only ----
        if Item."Routing Type" <> Item."Routing Type"::BULK then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_NotBulkItem, OutcomeNoLineTxt,
                       StrSubstNo(NotBulkTxt, Item."No.", Format(Item."Routing Type")), 0);
            exit;
        end;

        // ---- Rule 2: the report exits when no Bulk Bin Content exists ----
        // Mirrors the report: it resolves the bin from BIN CONTENT with the
        // Bulk flag, not from the Bin table, so an item with no content row
        // is skipped even when a Bulk bin exists.
        BinContent.Reset();
        BinContent.SetRange("Item No.", Item."No.");
        BinContent.SetRange("Location Code", MainLocation);
        BinContent.SetRange(Bulk, true);
        if BinCodeFilter <> '' then
            BinContent.SetRange("Bin Code", BinCodeFilter);
        if not BinContent.FindFirst() then begin
            AddBinFacts(Buffer, Item, MainLocation, '', ReceiveLocation, ReceiveBulkBin);
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_NoBulkBinContent, OutcomeNoLineTxt,
                       StrSubstNo(NoBulkBinTxt, Item."No.", MainLocation), 0);
            exit;
        end;
        MainBulkBin := BinContent."Bin Code";

        AddBinFacts(Buffer, Item, MainLocation, MainBulkBin, ReceiveLocation, ReceiveBulkBin);

        BinContent.CalcFields("Quantity (Base)");
        OnHand := BinContent."Quantity (Base)";
        QtyPerUoM := BinContent."Qty. per Unit of Measure";
        if QtyPerUoM = 0 then
            QtyPerUoM := 1;
        MinBaseQty := BinContent."Min. Qty." * QtyPerUoM;
        MaxBaseQty := BinContent."Max. Qty." * QtyPerUoM;

        // ---- Rule 4 input: outstanding Transfer Order pool ----
        TransferQty := GetOutstandingTransferQty(Item."No.", ReceiveLocation, MainLocation);
        EffectiveQty := OnHand + TransferQty;

        // ---- Rule 3: above minimum, nothing to do ----
        // The report triggers on (current + TO) <= Min AND Max > (current + TO).
        if EffectiveQty > MinBaseQty then begin
            if TransferQty > 0 then
                SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_CoveredByTransferOrder, OutcomeNoLineTxt,
                           StrSubstNo(CoveredByTOTxt, MainBulkBin, TypeHelperNewLine(),
                                      G_Facts.FormatQty(OnHand), G_Facts.FormatQty(TransferQty),
                                      G_Facts.FormatQty(EffectiveQty), G_Facts.FormatQty(MinBaseQty)), 0)
            else
                SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_AboveMinQty, OutcomeNoLineTxt,
                           StrSubstNo(AboveMinTxt, MainBulkBin, TypeHelperNewLine(),
                                      G_Facts.FormatQty(OnHand), G_Facts.FormatQty(MinBaseQty)), 0);
            exit;
        end;

        // No room to Max even though below Min - the report skips this too.
        if MaxBaseQty <= EffectiveQty then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_AboveMinQty, OutcomeNoLineTxt,
                       StrSubstNo(AboveMinTxt, MainBulkBin, TypeHelperNewLine(),
                                  G_Facts.FormatQty(OnHand), G_Facts.FormatQty(MinBaseQty)), 0);
            exit;
        end;

        QtyToReplenish := MaxBaseQty - EffectiveQty;

        // ---- Rule 5: is there usable FEFO source stock? ----
        SourceQty := GetUsableSourceQty(Item."No.", ReceiveLocation, ReceiveBulkBin);
        if SourceQty <= 0 then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_NoSourceStock, OutcomeNoLineTxt,
                       StrSubstNo(NoSourceTxt, MainBulkBin, G_Facts.FormatQty(QtyToReplenish), ReceiveBulkBin, TypeHelperNewLine()), 0);
            exit;
        end;

        // ---- Rule 6: duplicate guard ----
        if HasExistingWorksheetLine(Item."No.", ReceiveLocation, ReceiveBulkBin, MainLocation, MainBulkBin) then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_AlreadyOnWorksheet, OutcomeNoLineTxt,
                       StrSubstNo(AlreadyOnWkshTxt, MainBulkBin, G_Facts.FormatQty(QtyToReplenish)), 0);
            exit;
        end;

        // ---- Would replenish ----
        if SourceQty < QtyToReplenish then
            QtyToReplenish := SourceQty;

        SetVerdict(Buffer, "Routing Explanation Rule NDPP"::BR_WouldReplenish,
                   StrSubstNo(OutcomeWouldCreateTxt, G_Facts.FormatQty(QtyToReplenish)),
                   StrSubstNo(WouldReplenishTxt, MainBulkBin, TypeHelperNewLine(),
                              G_Facts.FormatQty(OnHand), G_Facts.FormatQty(MinBaseQty),
                              G_Facts.FormatQty(MaxBaseQty), G_Facts.FormatQty(QtyToReplenish), ReceiveBulkBin),
                   QtyToReplenish);
    end;

    /// <summary>
    /// Outstanding Transfer Order quantity Receive -> Main for this item.
    /// Mirrors the per-item pool the report sums before iterating bins.
    /// </summary>
    local procedure GetOutstandingTransferQty(ItemNo: Code[20]; FromLocation: Code[20]; ToLocation: Code[20]): Decimal
    var
        TransferLine: Record "Transfer Line";
    begin
        TransferLine.Reset();
        TransferLine.SetRange("Item No.", ItemNo);
        TransferLine.SetRange("Transfer-from Code", FromLocation);
        TransferLine.SetRange("Transfer-to Code", ToLocation);
        TransferLine.SetFilter("Outstanding Qty. (Base)", '>%1', 0);
        if TransferLine.IsEmpty() then
            exit(0);

        TransferLine.CalcSums("Outstanding Qty. (Base)");
        exit(TransferLine."Outstanding Qty. (Base)");
    end;

    /// <summary>
    /// Source stock the report would actually accept: positive qty, expiry on
    /// or after today, and a non-blank manufacturer code. The manufacturer
    /// filter is the usual reason stock is present but invisible to the
    /// calculation, so it is applied here identically.
    /// </summary>
    local procedure GetUsableSourceQty(ItemNo: Code[20]; LocationCode: Code[20]; BinCode: Code[20]): Decimal
    var
        WhseEntry: Record "Warehouse Entry";
    begin
        if BinCode = '' then
            exit(0);

        WhseEntry.Reset();
        WhseEntry.SetRange("Item No.", ItemNo);
        WhseEntry.SetRange("Location Code", LocationCode);
        WhseEntry.SetRange("Bin Code", BinCode);
        WhseEntry.SetFilter("Expiration Date", '>=%1', WorkDate());
        WhseEntry.SetFilter("Manufacturer Code", '<>%1', '');
        if WhseEntry.IsEmpty() then
            exit(0);

        WhseEntry.CalcSums("Qty. (Base)");
        if WhseEntry."Qty. (Base)" < 0 then
            exit(0);
        exit(WhseEntry."Qty. (Base)");
    end;

    /// <summary>
    /// Mirrors the report duplicate guard against Decant Details rows of type
    /// Replenishment for the same source / destination pair.
    /// </summary>
    local procedure HasExistingWorksheetLine(ItemNo: Code[20]; SourceLocation: Code[20]; SourceBin: Code[20]; DestLocation: Code[20]; DestBin: Code[20]): Boolean
    var
        DecantDetails: Record "Decant Details";
    begin
        DecantDetails.Reset();
        DecantDetails.SetRange("Entry Type", DecantDetails."Entry Type"::Replenishment);
        DecantDetails.SetRange("Item No.", ItemNo);
        DecantDetails.SetRange("Location Code", CopyStr(SourceLocation, 1, MaxStrLen(DecantDetails."Location Code")));
        DecantDetails.SetRange("From Bin Code", SourceBin);
        DecantDetails.SetRange("To Location Code", CopyStr(DestLocation, 1, MaxStrLen(DecantDetails."To Location Code")));
        DecantDetails.SetRange("To Bin Code", DestBin);
        exit(not DecantDetails.IsEmpty());
    end;

    local procedure AddBinFacts(var Buffer: Record "Routing Explanation NDPP" temporary; Item: Record Item; MainLocation: Code[20]; MainBulkBin: Code[20]; ReceiveLocation: Code[20]; ReceiveBulkBin: Code[20])
    begin
        if MainBulkBin <> '' then
            G_Facts.AddBinFact(Buffer, MainLocation, MainBulkBin, Item."No.", MainBinRoleTxt);
        G_Facts.AddBinFact(Buffer, ReceiveLocation, ReceiveBulkBin, Item."No.", ReceiveBinRoleTxt);
    end;

    /// <summary>
    /// Line break for the multi-line explanation text. Built from character
    /// codes rather than the System Application "Type Helper" codeunit, which
    /// this app does not have a dependency on.
    /// </summary>
    local procedure TypeHelperNewLine(): Text
    var
        CR: Char;
        LF: Char;
    begin
        CR := 13;
        LF := 10;
        exit(Format(CR) + Format(LF));
    end;

    local procedure SetVerdict(var Buffer: Record "Routing Explanation NDPP" temporary; Rule: Enum "Routing Explanation Rule NDPP"; OutcomeText: Text; ExplanationText: Text; RoomAvailable: Decimal)
    begin
        Buffer.Reset();
        Buffer.SetRange("Row Type", Buffer."Row Type"::Header);
        if not Buffer.FindFirst() then begin
            Buffer.Reset();
            exit;
        end;

        Buffer."Rule Applied" := Rule;
        Buffer.Outcome := CopyStr(OutcomeText, 1, MaxStrLen(Buffer.Outcome));
        Buffer.Explanation := CopyStr(ExplanationText, 1, MaxStrLen(Buffer.Explanation));
        Buffer."Room Available" := RoomAvailable;
        Buffer."Evaluated At" := CurrentDateTime();
        Buffer.Modify();
        Buffer.Reset();
    end;
}
