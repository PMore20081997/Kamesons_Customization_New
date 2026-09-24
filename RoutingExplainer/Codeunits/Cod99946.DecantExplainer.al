namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using System.Utilities;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Explains Decant calculation in plain English for page 99941.
///
/// MIRRORS codeunit 99991 "Create Decant Whse Reclass And Post" - the source
/// buffer load, the destination bin resolution and the tote-based allocation.
/// Tote arithmetic is NOT re-implemented: it calls codeunit 99962
/// "Kam Tote Math", which is pure read-only, so the screen and the engine
/// count totes identically by construction.
///
/// The rule users find least intuitive is tote rounding - a partial tote
/// occupies a whole slot, so 190 units at 100 per tote fills 2 totes. Most
/// decant questions are answered by stating that in words.
///
///   1. Item is not Flowrack / Static          (BinFlagMatchesRoutingType)
///   2. No matching destination bin in Main WH
///   3. No Qty per Tote for the item/manufacturer
///   4. Destination bin has no empty totes
///   5. No usable source stock in the Receive bins
///   6. Limited by empty totes, or by available source
///
/// When the engine changes, update this codeunit and enum 99943 together.
/// </summary>
codeunit 99946 "Decant Explainer NDPP"
{
    Access = Public;
    Permissions = tabledata "Bin Content" = r,
                  tabledata Bin = r,
                  tabledata Item = r,
                  tabledata "Warehouse Entry" = r,
                  tabledata "Item Manufacturer Table" = r;

    var
        G_Facts: Codeunit "Routing Explainer Facts NDPP";
        G_ToteMath: Codeunit "Kam Tote Math";
        NotDecantItemTxt: Label 'Item %1 has a routing type of %2. Decant only handles Flowrack and Static items - BULK items are replenished through the Bulk Replenishment worksheet instead, so this item will never appear on the Decant screen.', Comment = '%1 = Item No.; %2 = routing type';
        NoDestBinTxt: Label 'Item %1 has no %2-flagged bin holding stock in %3. Decant needs a destination bin in the Main Warehouse before it can move anything. Ask your supervisor to set up the bin content.', Comment = '%1 = Item No.; %2 = routing type; %3 = Main location';
        NoQtyPerToteTxt: Label 'No Qty per Tote is set up for item %1 against any manufacturer. Decant works in whole totes, so without this figure it cannot calculate how much to move. Set Qty per Tote on the Item Manufacturer record.', Comment = '%1 = Item No.';
        NoEmptyTotesTxt: Label 'Destination bin %1 has no empty totes:%2%2   Totes the bin holds  %3%2   Totes now occupied   %4%2%2A tote counts as occupied even when only partly filled - %5 units at %6 per tote fills %7 totes. Until stock is picked from this bin, there is nowhere for a decant to go.', Comment = '%1 = bin; %2 = newline; %3 = capacity; %4 = occupied; %5 = on hand; %6 = qty per tote; %7 = totes used';
        NoSourceTxt: Label 'Destination bin %1 has %2 empty tote(s) ready, but there is no usable stock to move from the Receive bins.%3%3Source stock needs a quantity above zero, an expiry date on or after today, and a manufacturer code. Stock without a manufacturer code is skipped, which is the most common cause.', Comment = '%1 = bin; %2 = empty totes; %3 = newline';
        LimitedByTotesTxt: Label 'Decant is limited by the space in bin %1, not by stock:%2%2   Empty totes available %3%2   Qty per tote          %4%2   Most that can move    %5%2   Stock available       %6%2%2Even though %6 is available, only %5 can be moved because that is what the empty totes hold. The rest stays where it is until more totes free up.', Comment = '%1 = bin; %2 = newline; %3 = empty totes; %4 = qty per tote; %5 = max movable; %6 = source qty';
        LimitedBySourceTxt: Label 'Decant is limited by available stock, not by space:%1%1   Empty totes available %2%1   Most the bin could take %3%1   Stock available        %4%1%1Only %4 can be moved because that is all the Receive bins hold for this item. Stock is taken in expiry-date order, oldest first.', Comment = '%1 = newline; %2 = empty totes; %3 = capacity; %4 = source qty';
        OutcomeNoLineTxt: Label 'No decant line would be created for this item.';
        OutcomeWouldMoveTxt: Label 'A decant of up to %1 would be created.', Comment = '%1 = qty';
        MainBinRoleTxt: Label 'Main WH decant face';
        ReceiveFaceRoleTxt: Label 'Receive decant face';
        HighBayRoleTxt: Label 'Receive High Bay';

    /// <summary>
    /// Fills the buffer with the Decant explanation for one item.
    /// </summary>
    procedure Explain(var Buffer: Record "Routing Explanation NDPP" temporary; Item: Record Item; BinCodeFilter: Code[20])
    var
        DestBinContent: Record "Bin Content";
        MainLocation: Code[20];
        ReceiveLocation: Code[20];
        ReceiveFaceBin: Code[20];
        HighBayBin: Code[20];
        DestBin: Code[20];
        QtyPerTote: Decimal;
        ToteCapacity: Integer;
        TotesOccupied: Integer;
        EmptyTotes: Integer;
        OnHand: Decimal;
        MovableQty: Decimal;
        SourceQty: Decimal;
        DecantEntryType: Option Decant,Replenishment;
    begin
        MainLocation := G_Facts.GetMainLocation();
        ReceiveLocation := G_Facts.GetReceiveLocation();
        ReceiveFaceBin := G_Facts.FindFlaggedBin(ReceiveLocation, Item."Routing Type", false);
        HighBayBin := G_Facts.FindFlaggedBin(ReceiveLocation, Item."Routing Type", true);

        // Worksheet history for this item - shown whatever the verdict, so the
        // user can see what decant has already planned or posted.
        G_Facts.AddRecentDecantActivity(Buffer, Item."No.", DecantEntryType::Decant, 10);

        // ---- Rule 1: BinFlagMatchesRoutingType handles Flowrack / Static only ----
        if not (Item."Routing Type" in [Item."Routing Type"::Flowrack, Item."Routing Type"::"Static"]) then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::DC_NotDecantItem, OutcomeNoLineTxt,
                       StrSubstNo(NotDecantItemTxt, Item."No.", Format(Item."Routing Type")), 0);
            exit;
        end;

        // ---- Rule 2: a destination bin holding this item must exist ----
        if not TryGetDestBinContent(Item, MainLocation, BinCodeFilter, DestBinContent) then begin
            AddBinFacts(Buffer, Item, MainLocation, '', ReceiveLocation, ReceiveFaceBin, HighBayBin);
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::DC_NoDestinationBin, OutcomeNoLineTxt,
                       StrSubstNo(NoDestBinTxt, Item."No.", Format(Item."Routing Type"), MainLocation), 0);
            exit;
        end;
        DestBin := DestBinContent."Bin Code";

        AddBinFacts(Buffer, Item, MainLocation, DestBin, ReceiveLocation, ReceiveFaceBin, HighBayBin);

        // ---- Rule 3: Qty per Tote must be configured ----
        QtyPerTote := GetAnyQtyPerTote(Item."No.");
        if QtyPerTote <= 0 then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::DC_NoQtyPerTote, OutcomeNoLineTxt,
                       StrSubstNo(NoQtyPerToteTxt, Item."No."), 0);
            exit;
        end;

        // ---- Rule 4: empty totes in the destination bin ----
        // Tote counting is delegated to Cod99962 so the screen and the engine
        // round identically (partial tote occupies a whole slot).
        ToteCapacity := DestBinContent."Number of Totes in a Bin";
        TotesOccupied := G_ToteMath.CountTotesInFLOWRACKBin(DestBinContent);
        EmptyTotes := ToteCapacity - TotesOccupied;
        if EmptyTotes < 0 then
            EmptyTotes := 0;

        DestBinContent.CalcFields("Quantity (Base)");
        OnHand := DestBinContent."Quantity (Base)";

        if EmptyTotes <= 0 then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::DC_NoEmptyTotes, OutcomeNoLineTxt,
                       StrSubstNo(NoEmptyTotesTxt, DestBin, TypeHelperNewLine(),
                                  Format(ToteCapacity), Format(TotesOccupied),
                                  G_Facts.FormatQty(OnHand), G_Facts.FormatQty(QtyPerTote), Format(TotesOccupied)), 0);
            exit;
        end;

        MovableQty := EmptyTotes * QtyPerTote;

        // ---- Rule 5: usable source stock across Receive face and High Bay ----
        SourceQty := GetUsableSourceQty(Item."No.", ReceiveLocation, ReceiveFaceBin) +
                     GetUsableSourceQty(Item."No.", ReceiveLocation, HighBayBin);
        if SourceQty <= 0 then begin
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::DC_NoSourceStock, OutcomeNoLineTxt,
                       StrSubstNo(NoSourceTxt, DestBin, Format(EmptyTotes), TypeHelperNewLine()), 0);
            exit;
        end;

        // ---- Rule 6: which constraint binds ----
        if MovableQty <= SourceQty then
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::DC_LimitedByTotes,
                       StrSubstNo(OutcomeWouldMoveTxt, G_Facts.FormatQty(MovableQty)),
                       StrSubstNo(LimitedByTotesTxt, DestBin, TypeHelperNewLine(),
                                  Format(EmptyTotes), G_Facts.FormatQty(QtyPerTote),
                                  G_Facts.FormatQty(MovableQty), G_Facts.FormatQty(SourceQty)), MovableQty)
        else
            SetVerdict(Buffer, "Routing Explanation Rule NDPP"::DC_LimitedBySource,
                       StrSubstNo(OutcomeWouldMoveTxt, G_Facts.FormatQty(SourceQty)),
                       StrSubstNo(LimitedBySourceTxt, TypeHelperNewLine(),
                                  Format(EmptyTotes), G_Facts.FormatQty(MovableQty),
                                  G_Facts.FormatQty(SourceQty)), SourceQty);
    end;

    /// <summary>
    /// The Main-WH Bin Content row decant would fill: a bin carrying the flag
    /// matching the item routing type. Honours an explicit bin filter when the
    /// user named one.
    /// </summary>
    local procedure TryGetDestBinContent(Item: Record Item; MainLocation: Code[20]; BinCodeFilter: Code[20]; var DestBinContent: Record "Bin Content"): Boolean
    begin
        DestBinContent.Reset();
        DestBinContent.SetRange("Item No.", Item."No.");
        DestBinContent.SetRange("Location Code", MainLocation);
        if BinCodeFilter <> '' then
            DestBinContent.SetRange("Bin Code", BinCodeFilter);

        case Item."Routing Type" of
            Item."Routing Type"::Flowrack:
                DestBinContent.SetRange(Flowrack, true);
            Item."Routing Type"::"Static":
                DestBinContent.SetRange("Static", true);
            else
                exit(false);
        end;

        exit(DestBinContent.FindFirst());
    end;

    /// <summary>
    /// Highest Qty per Tote configured for the item across its manufacturers.
    /// Used only to decide whether tote setup exists at all and to phrase the
    /// explanation; the engine uses the per-manufacturer figure.
    /// </summary>
    local procedure GetAnyQtyPerTote(ItemNo: Code[20]): Decimal
    var
        ItemMfr: Record "Item Manufacturer Table";
        BestQty: Decimal;
    begin
        ItemMfr.Reset();
        ItemMfr.SetRange("Item No", ItemNo);
        ItemMfr.SetFilter("Qty per Tote", '>%1', 0);
        if not ItemMfr.FindSet() then
            exit(0);

        repeat
            if ItemMfr."Qty per Tote" > BestQty then
                BestQty := ItemMfr."Qty per Tote";
        until ItemMfr.Next() = 0;

        exit(BestQty);
    end;

    /// <summary>
    /// Source stock the decant engine would accept from a Receive bin:
    /// positive qty, expiry on or after today, non-blank manufacturer code.
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

    local procedure AddBinFacts(var Buffer: Record "Routing Explanation NDPP" temporary; Item: Record Item; MainLocation: Code[20]; DestBin: Code[20]; ReceiveLocation: Code[20]; ReceiveFaceBin: Code[20]; HighBayBin: Code[20])
    var
        TempBin: Record Bin temporary;
    begin
        if DestBin <> '' then
            AddDecantBinFact(Buffer, MainLocation, DestBin, Item."No.")
        else begin
            G_Facts.FindMainBinsForItem(Item."No.", Item."Routing Type", TempBin);
            if TempBin.FindSet() then
                repeat
                    AddDecantBinFact(Buffer, MainLocation, TempBin.Code, Item."No.");
                until TempBin.Next() = 0;
        end;

        G_Facts.AddBinFact(Buffer, ReceiveLocation, ReceiveFaceBin, Item."No.", ReceiveFaceRoleTxt);
        G_Facts.AddBinFact(Buffer, ReceiveLocation, HighBayBin, Item."No.", HighBayRoleTxt);
    end;

    /// <summary>
    /// Bin fact row with the tote figures filled in - the decant screen needs
    /// empty totes and Qty per Tote, which the shared helper does not carry.
    /// </summary>
    local procedure AddDecantBinFact(var Buffer: Record "Routing Explanation NDPP" temporary; LocationCode: Code[20]; BinCode: Code[20]; ItemNo: Code[20])
    var
        BinContent: Record "Bin Content";
        EmptyTotes: Integer;
    begin
        G_Facts.AddBinFact(Buffer, LocationCode, BinCode, ItemNo, MainBinRoleTxt);

        BinContent.Reset();
        BinContent.SetRange("Location Code", LocationCode);
        BinContent.SetRange("Bin Code", BinCode);
        BinContent.SetRange("Item No.", ItemNo);
        if not BinContent.FindFirst() then
            exit;

        EmptyTotes := BinContent."Number of Totes in a Bin" - G_ToteMath.CountTotesInFLOWRACKBin(BinContent);
        if EmptyTotes < 0 then
            EmptyTotes := 0;

        Buffer.Reset();
        if Buffer.FindLast() then begin
            Buffer."Empty Totes" := EmptyTotes;
            Buffer."Qty Per Tote" := GetAnyQtyPerTote(ItemNo);
            Buffer.Modify();
        end;
        Buffer.Reset();
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
