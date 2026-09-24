namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Shared read-only fact gathering for the three explainer codeunits
/// (99944 Put-Away, 99945 Bulk Replen, 99946 Decant).
///
/// Pure reads. No inserts into anything except the caller's TEMPORARY
/// explanation buffer. Every figure here is read the same way the live
/// engines read it, so the explanation matches what the engine would decide.
/// </summary>
codeunit 99948 "Routing Explainer Facts NDPP"
{
    Access = Public;
    Permissions = tabledata "Bin Content" = r,
                  tabledata Bin = r,
                  tabledata Item = r,
                  tabledata "Warehouse Entry" = r,
                  tabledata "Warehouse Activity Line" = r;

    var
        G_Setup: Codeunit "Kam Whse Setup Lookup";
        FromBinTxt: Label 'From %1', Comment = '%1 = source bin code';

    /// <summary>
    /// Resolves an item from either an item number or a scanned barcode.
    /// Mirrors the barcode lookup already used on the Decant Screen
    /// (page 99991), so a scan behaves identically on both screens.
    /// </summary>
    procedure ResolveItem(ItemNo: Code[20]; Barcode: Code[50]; var Item: Record Item): Boolean
    var
        ItemReference: Record "Item Reference";
    begin
        if ItemNo <> '' then
            exit(Item.Get(ItemNo));

        if Barcode = '' then
            exit(false);

        ItemReference.Reset();
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
        ItemReference.SetRange("Reference No.", Barcode);
        if not ItemReference.FindFirst() then
            exit(false);

        exit(Item.Get(ItemReference."Item No."));
    end;

    procedure GetMainLocation(): Code[20]
    begin
        exit(G_Setup.GetMainLocation());
    end;

    procedure GetReceiveLocation(): Code[20]
    begin
        exit(G_Setup.GetReceiveLocation());
    end;

    /// <summary>
    /// On-hand base qty for an item in one bin, read from Bin Content the
    /// same way the engines do.
    /// </summary>
    procedure GetBinOnHand(LocationCode: Code[20]; BinCode: Code[20]; ItemNo: Code[20]): Decimal
    var
        BinContent: Record "Bin Content";
    begin
        BinContent.Reset();
        BinContent.SetRange("Location Code", LocationCode);
        BinContent.SetRange("Bin Code", BinCode);
        BinContent.SetRange("Item No.", ItemNo);
        if not BinContent.FindFirst() then
            exit(0);

        BinContent.CalcFields("Quantity (Base)");
        exit(BinContent."Quantity (Base)");
    end;

    /// <summary>
    /// Min / Max in BASE units for an item in one bin. Returns FALSE when the
    /// item has no Bin Content row there - which is itself a finding, since
    /// the Put-Away master-data gate sends such items to High Bay.
    /// </summary>
    procedure TryGetBinLimits(LocationCode: Code[20]; BinCode: Code[20]; ItemNo: Code[20]; var MinBaseQty: Decimal; var MaxBaseQty: Decimal; var QtyPerUoM: Decimal): Boolean
    var
        BinContent: Record "Bin Content";
    begin
        Clear(MinBaseQty);
        Clear(MaxBaseQty);
        QtyPerUoM := 1;

        BinContent.Reset();
        BinContent.SetRange("Location Code", LocationCode);
        BinContent.SetRange("Bin Code", BinCode);
        BinContent.SetRange("Item No.", ItemNo);
        if not BinContent.FindFirst() then
            exit(false);

        QtyPerUoM := BinContent."Qty. per Unit of Measure";
        if QtyPerUoM = 0 then
            QtyPerUoM := 1;

        MinBaseQty := BinContent."Min. Qty." * QtyPerUoM;
        MaxBaseQty := BinContent."Max. Qty." * QtyPerUoM;
        exit(true);
    end;

    /// <summary>
    /// Earliest / latest expiry held for an item in a bin, from Warehouse
    /// Entry. Zero dates mean the bin holds no positive-qty stock.
    /// </summary>
    procedure GetBinExpiryRange(LocationCode: Code[20]; BinCode: Code[20]; ItemNo: Code[20]; var EarliestExpiry: Date; var LatestExpiry: Date)
    var
        WhseEntry: Record "Warehouse Entry";
    begin
        Clear(EarliestExpiry);
        Clear(LatestExpiry);

        WhseEntry.Reset();
        WhseEntry.SetRange("Location Code", LocationCode);
        WhseEntry.SetRange("Bin Code", BinCode);
        WhseEntry.SetRange("Item No.", ItemNo);
        WhseEntry.SetFilter("Expiration Date", '<>%1', 0D);
        if not WhseEntry.FindSet() then
            exit;

        repeat
            if (EarliestExpiry = 0D) or (WhseEntry."Expiration Date" < EarliestExpiry) then
                EarliestExpiry := WhseEntry."Expiration Date";
            if WhseEntry."Expiration Date" > LatestExpiry then
                LatestExpiry := WhseEntry."Expiration Date";
        until WhseEntry.Next() = 0;
    end;

    /// <summary>
    /// Qty sitting on unregistered Put-Away Place lines heading into a bin -
    /// stock that is committed but not yet in Bin Content. The engines net
    /// this off, so the explanation must show it or the numbers will not add up.
    /// </summary>
    procedure GetPendingPlaceQty(LocationCode: Code[20]; BinCode: Code[20]; ItemNo: Code[20]): Decimal
    var
        WhseActLine: Record "Warehouse Activity Line";
    begin
        WhseActLine.Reset();
        WhseActLine.SetRange("Location Code", LocationCode);
        WhseActLine.SetRange("Bin Code", BinCode);
        WhseActLine.SetRange("Item No.", ItemNo);
        WhseActLine.SetRange("Activity Type", WhseActLine."Activity Type"::"Put-away");
        WhseActLine.SetRange("Action Type", WhseActLine."Action Type"::Place);
        if WhseActLine.IsEmpty() then
            exit(0);

        WhseActLine.CalcSums("Qty. (Base)");
        exit(WhseActLine."Qty. (Base)");
    end;

    /// <summary>
    /// The bin in a location carrying the given routing flag. Blank when the
    /// flag is not configured there - the caller reports that as a setup gap
    /// rather than erroring, unlike the hard Error() variants in
    /// codeunit 99961.
    /// </summary>
    procedure FindFlaggedBin(LocationCode: Code[20]; RoutingType: Enum "Item Routing Type NDPP"; HighBay: Boolean): Code[20]
    var
        Bin: Record Bin;
    begin
        Bin.Reset();
        Bin.SetRange("Location Code", LocationCode);
        if HighBay then
            Bin.SetRange(HighBay, true)
        else
            case RoutingType of
                RoutingType::BULK:
                    Bin.SetRange(Bulk, true);
                RoutingType::"Static":
                    Bin.SetRange("Static", true);
                RoutingType::Flowrack:
                    Bin.SetRange(Flowrack, true);
            end;

        if Bin.FindFirst() then
            exit(Bin.Code);
        exit('');
    end;

    /// <summary>
    /// All Main-WH bins holding Bin Content for this item under its routing
    /// flag. Flowrack and Static items can legitimately span several bins,
    /// so the screen reports each one rather than only the first.
    /// </summary>
    procedure FindMainBinsForItem(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"; var TempBinBuffer: Record Bin temporary)
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
        MainLocation: Code[20];
    begin
        TempBinBuffer.Reset();
        TempBinBuffer.DeleteAll();

        MainLocation := G_Setup.GetMainLocation();

        Bin.Reset();
        Bin.SetRange("Location Code", MainLocation);
        case RoutingType of
            RoutingType::BULK:
                Bin.SetRange(Bulk, true);
            RoutingType::"Static":
                Bin.SetRange("Static", true);
            RoutingType::Flowrack:
                Bin.SetRange(Flowrack, true);
        end;
        if not Bin.FindSet() then
            exit;

        repeat
            BinContent.Reset();
            BinContent.SetRange("Location Code", MainLocation);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if not BinContent.IsEmpty() then begin
                TempBinBuffer := Bin;
                if TempBinBuffer.Insert() then;
            end;
        until Bin.Next() = 0;
    end;

    /// <summary>
    /// Adds one Bin Fact row to the explanation buffer, filling the figures
    /// from live data. Used by all three explainers so every screen shows the
    /// same shape of evidence.
    /// </summary>
    procedure AddBinFact(var Buffer: Record "Routing Explanation NDPP" temporary; LocationCode: Code[20]; BinCode: Code[20]; ItemNo: Code[20]; RoleText: Text)
    var
        MinBaseQty: Decimal;
        MaxBaseQty: Decimal;
        QtyPerUoM: Decimal;
        EarliestExpiry: Date;
        LatestExpiry: Date;
    begin
        if BinCode = '' then
            exit;

        Buffer.InitRow(Buffer, Buffer."Row Type"::BinFact);
        Buffer."Fact Location Code" := CopyStr(LocationCode, 1, MaxStrLen(Buffer."Fact Location Code"));
        Buffer."Fact Bin Code" := BinCode;
        Buffer."Bin Role" := CopyStr(RoleText, 1, MaxStrLen(Buffer."Bin Role"));
        Buffer."Qty On Hand" := GetBinOnHand(LocationCode, BinCode, ItemNo);

        if TryGetBinLimits(LocationCode, BinCode, ItemNo, MinBaseQty, MaxBaseQty, QtyPerUoM) then begin
            Buffer."Min Qty" := MinBaseQty;
            Buffer."Max Qty" := MaxBaseQty;
        end;

        GetBinExpiryRange(LocationCode, BinCode, ItemNo, EarliestExpiry, LatestExpiry);
        Buffer."Earliest Expiry" := EarliestExpiry;
        Buffer."Latest Expiry" := LatestExpiry;
        Buffer."Qty In Flight" := GetPendingPlaceQty(LocationCode, BinCode, ItemNo);
        Buffer.Insert();
    end;

    /// <summary>
    /// Recent Put-Away Place lines for an item, newest first. This is what
    /// ties the screen back to the question users actually ask - it shows the
    /// two lines of a split sitting next to each other.
    /// </summary>
    procedure AddRecentPutAwayActivity(var Buffer: Record "Routing Explanation NDPP" temporary; ItemNo: Code[20]; MaxRows: Integer)
    var
        WhseActLine: Record "Warehouse Activity Line";
        RowCount: Integer;
    begin
        WhseActLine.Reset();
        WhseActLine.SetRange("Item No.", ItemNo);
        WhseActLine.SetRange("Activity Type", WhseActLine."Activity Type"::"Put-away");
        WhseActLine.SetRange("Action Type", WhseActLine."Action Type"::Place);
        // Newest first: the split that prompted the question is a recent one.
        WhseActLine.Ascending(false);
        if not WhseActLine.FindSet() then
            exit;

        repeat
            Buffer.InitRow(Buffer, Buffer."Row Type"::Activity);
            Buffer."Activity Date" := WhseActLine."Due Date";
            Buffer."Document No." := WhseActLine."No.";
            Buffer."Activity Qty" := WhseActLine."Qty. (Base)";
            Buffer."Activity Bin Code" := WhseActLine."Bin Code";
            Buffer."Activity Expiry" := WhseActLine."Expiration Date";
            Buffer."Activity Description" := CopyStr(Format(WhseActLine."Source Document"), 1, MaxStrLen(Buffer."Activity Description"));
            Buffer.Insert();
            RowCount += 1;
        until (WhseActLine.Next() = 0) or (RowCount >= MaxRows);
    end;

    /// <summary>
    /// Recent Decant Details worksheet lines for an item, for the Decant and
    /// Bulk Replenishment views. Put-Away history lives on Warehouse Activity
    /// Lines, but decant and replenishment plan their work on Decant Details -
    /// so this is the equivalent "what actually happened" trail for them.
    ///
    /// EntryTypeFilter picks which side to show: Replenishment rows for the
    /// Bulk Replen view, Decant rows for the Decant view.
    /// </summary>
    procedure AddRecentDecantActivity(var Buffer: Record "Routing Explanation NDPP" temporary; ItemNo: Code[20]; EntryTypeFilter: Option Decant,Replenishment; MaxRows: Integer)
    var
        DecantDetails: Record "Decant Details";
        RowCount: Integer;
    begin
        DecantDetails.Reset();
        DecantDetails.SetRange("Item No.", ItemNo);
        DecantDetails.SetRange("Entry Type", EntryTypeFilter);
        // Newest first: the lines that prompted the question are the recent ones.
        DecantDetails.SetCurrentKey("Line No.");
        DecantDetails.Ascending(false);
        if not DecantDetails.FindSet() then
            exit;

        repeat
            Buffer.InitRow(Buffer, Buffer."Row Type"::Activity);
            Buffer."Activity Date" := DecantDetails."Posting Date";
            Buffer."Document No." := DecantDetails."Journal Batch Name";
            Buffer."Activity Qty" := DecantDetails."To Qty.";
            Buffer."Activity Bin Code" := DecantDetails."To Bin Code";
            Buffer."Activity Expiry" := DecantDetails."Expiry Date";
            Buffer."Activity Description" := CopyStr(StrSubstNo(FromBinTxt, DecantDetails."From Bin Code"), 1, MaxStrLen(Buffer."Activity Description"));
            Buffer.Insert();
            RowCount += 1;
        until (DecantDetails.Next() = 0) or (RowCount >= MaxRows);
    end;

    /// <summary>
    /// Formats a base quantity for use inside an explanation sentence.
    /// Whole numbers print without decimals so the text reads naturally.
    /// </summary>
    procedure FormatQty(BaseQty: Decimal): Text
    begin
        if BaseQty = Round(BaseQty, 1) then
            exit(Format(Round(BaseQty, 1), 0, '<Integer Thousand>'));
        exit(Format(BaseQty, 0, '<Precision,0:2><Standard Format,0>'));
    end;

    procedure FormatDate(TheDate: Date): Text
    begin
        if TheDate = 0D then
            exit('-');
        exit(Format(TheDate, 0, '<Day,2>/<Month,2>/<Year4>'));
    end;
}
