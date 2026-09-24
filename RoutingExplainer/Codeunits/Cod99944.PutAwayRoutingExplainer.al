namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Ledger;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Explains Put-Away routing in plain English for page 99941.
///
/// MIRRORS codeunit 99983 "Put-Away Mgt. NDPP".RoutePutAwayLine - same rules,
/// same order, same data sources. It deliberately does NOT call the engine:
/// the engine mutates a Warehouse Activity Line and splits records, which a
/// diagnostic screen must never do.
///
/// RULE ORDER (keep in step with Cod99983):
///   1. No Main-WH Bin Content for the routing type        -> High Bay
///   2. Older High Bay stock covers Main shortfall         -> High Bay
///   3. Older High Bay stock covers only part of it        -> face, capped
///   4. Face below Min Qty                                 -> face, top up
///   5. Incoming expiry newer than the face                -> High Bay
///   6. Face at / over capacity                            -> High Bay
///   7. Face has partial room                              -> split
///
/// When the engine changes, update this codeunit and enum 99943 together.
/// </summary>
codeunit 99944 "Put-Away Explainer NDPP"
{
    Access = Public;
    Permissions = tabledata "Bin Content" = r,
                  tabledata Bin = r,
                  tabledata Item = r,
                  tabledata "Warehouse Entry" = r;

    var
        G_Facts: Codeunit "Routing Explainer Facts NDPP";
        NoMasterDataTxt: Label 'Item %1 has no bin set up in the Main Warehouse for %2 stock. Until a bin is configured, everything received for this item is sent to %3. Ask your supervisor to set up the bin content in the Main Warehouse.', Comment = '%1 = Item No.; %2 = routing type; %3 = High Bay bin';
        HighBayCoversTxt: Label '%1 already holds %2 of this item expiring %3, which is older than stock arriving now. Under FEFO that older stock must reach the pick face first, so newly received stock waits in %1 until it has been used.', Comment = '%1 = High Bay bin; %2 = qty; %3 = expiry date';
        HighBayPartialTxt: Label '%1 holds %2 of older stock (expiring %3), but the pick face %4 is %5 short of its minimum. The older stock alone cannot fill the gap, so incoming stock tops the face up by %6 and the rest goes to %1 - leaving room for the older stock to land later.', Comment = '%1 = High Bay bin; %2 = older qty; %3 = expiry; %4 = face bin; %5 = shortfall; %6 = net shortfall';
        BelowMinTxt: Label 'The %1 face is below its minimum (%2 on hand, minimum %3). It is topped up from incoming stock regardless of expiry date, so the pick face does not run dry. Up to %4 can be placed before the %5 maximum is reached.', Comment = '%1 = bin; %2 = on hand; %3 = min; %4 = room; %5 = max';
        ExpiryNewerTxt: Label 'The %1 face already holds stock expiring %2. Stock arriving now expires later, and the face must always hold the oldest stock first (FEFO). Newer stock is therefore sent to %3 and will reach the face later through the decant process.', Comment = '%1 = face bin; %2 = latest expiry on face; %3 = High Bay bin';
        FaceFullTxt: Label 'The %1 face is already at its maximum (%2 on hand against a maximum of %3). There is no room, so everything received goes to %4 until the face has been drawn down.', Comment = '%1 = face bin; %2 = on hand; %3 = max; %4 = High Bay bin';
        SplitTxt: Label 'The %1 face has room for %2 only (maximum %3, with %4 already on hand%5). Anything received above %2 will not fit, so the put-away is SPLIT: up to %2 goes to %1 and the remainder goes to %6. This is why one receipt can produce two Place lines. It is expected behaviour, not an error.', Comment = '%1 = face bin; %2 = room; %3 = max; %4 = on hand; %5 = in-flight clause; %6 = High Bay bin';
        InFlightClauseTxt: Label ' and %1 already on its way in', Comment = '%1 = in-flight qty';
        OutcomeSplitTxt: Label 'Stock received now would be SPLIT between %1 and %2.', Comment = '%1 = face bin; %2 = High Bay bin';
        OutcomeToHighBayTxt: Label 'Stock received now would go to %1.', Comment = '%1 = High Bay bin';
        OutcomeToFaceTxt: Label 'Stock received now would go to %1.', Comment = '%1 = face bin';
        NoHighBayBinTxt: Label 'No bin flagged as High Bay exists in %1. Put-Away routing cannot send overflow anywhere until one is set up.', Comment = '%1 = location';
        NoFaceBinTxt: Label 'No bin flagged as %1 exists in %2, so this item has no decant face to be put away to.', Comment = '%1 = routing type; %2 = location';

    /// <summary>
    /// Fills the buffer with the Put-Away explanation for one item.
    /// The Header row must already exist and carry the user input.
    /// </summary>
    procedure Explain(var Buffer: Record "Routing Explanation NDPP" temporary; Item: Record Item; BinCodeFilter: Code[20])
    var
        Header: Record "Routing Explanation NDPP" temporary;
        MainLocation: Code[20];
        ReceiveLocation: Code[20];
        FaceBin: Code[20];
        HighBayBin: Code[20];
        MainFaceBin: Code[20];
        OnHand: Decimal;
        InFlight: Decimal;
        MinBaseQty: Decimal;
        MaxBaseQty: Decimal;
        QtyPerUoM: Decimal;
        RoomAvailable: Decimal;
        HighBayOlderQty: Decimal;
        HighBayEarliest: Date;
        HighBayLatest: Date;
        FaceEarliest: Date;
        FaceLatest: Date;
        Shortfall: Decimal;
        NetShortfall: Decimal;
        InFlightClause: Text;
    begin
        MainLocation := G_Facts.GetMainLocation();
        ReceiveLocation := G_Facts.GetReceiveLocation();

        // Receive-side bins: where put-away actually places stock.
        FaceBin := G_Facts.FindFlaggedBin(ReceiveLocation, Item."Routing Type", false);
        HighBayBin := G_Facts.FindFlaggedBin(ReceiveLocation, Item."Routing Type", true);

        // Main-WH face: the bin whose Min / Max govern the capacity rules.
        MainFaceBin := G_Facts.FindFlaggedBin(MainLocation, Item."Routing Type", false);
        if BinCodeFilter <> '' then
            MainFaceBin := BinCodeFilter;

        AddBinFacts(Buffer, Item, MainLocation, ReceiveLocation, MainFaceBin, FaceBin, HighBayBin);
        G_Facts.AddRecentPutAwayActivity(Buffer, Item."No.", 10);

        GetHeader(Buffer, Header);
        Header."Target Bin Code" := FaceBin;
        Header."Overflow Bin Code" := HighBayBin;

        // ---- Setup gaps: report rather than guess ----
        if FaceBin = '' then begin
            SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_NoMasterData,
                       StrSubstNo(OutcomeToHighBayTxt, HighBayBin),
                       StrSubstNo(NoFaceBinTxt, Format(Item."Routing Type"), ReceiveLocation));
            exit;
        end;
        if HighBayBin = '' then begin
            SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_NoMasterData,
                       StrSubstNo(OutcomeToFaceTxt, FaceBin),
                       StrSubstNo(NoHighBayBinTxt, ReceiveLocation));
            exit;
        end;

        // ---- Rule 1: master-data gate (Cod99983 step 2) ----
        if not HasMainBinContent(Item, MainLocation) then begin
            SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_NoMasterData,
                       StrSubstNo(OutcomeToHighBayTxt, HighBayBin),
                       StrSubstNo(NoMasterDataTxt, Item."No.", Format(Item."Routing Type"), HighBayBin));
            exit;
        end;

        // Figures the remaining rules share.
        OnHand := G_Facts.GetBinOnHand(MainLocation, MainFaceBin, Item."No.");
        InFlight := G_Facts.GetPendingPlaceQty(ReceiveLocation, FaceBin, Item."No.");
        if not G_Facts.TryGetBinLimits(MainLocation, MainFaceBin, Item."No.", MinBaseQty, MaxBaseQty, QtyPerUoM) then begin
            SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_NoMasterData,
                       StrSubstNo(OutcomeToHighBayTxt, HighBayBin),
                       StrSubstNo(NoMasterDataTxt, Item."No.", Format(Item."Routing Type"), HighBayBin));
            exit;
        end;

        RoomAvailable := MaxBaseQty - OnHand - InFlight;
        if RoomAvailable < 0 then
            RoomAvailable := 0;
        Header."Room Available" := RoomAvailable;

        G_Facts.GetBinExpiryRange(ReceiveLocation, HighBayBin, Item."No.", HighBayEarliest, HighBayLatest);
        G_Facts.GetBinExpiryRange(MainLocation, MainFaceBin, Item."No.", FaceEarliest, FaceLatest);

        // ---- Rules 2 and 3: High Bay older-stock guard (Cod99983 step 3a) ----
        // The engine compares against the INCOMING line's expiry. With no line
        // to hand, the screen reports what High Bay holds and what the face
        // still needs, which is the same evidence in reportable form.
        if HighBayEarliest <> 0D then begin
            HighBayOlderQty := G_Facts.GetBinOnHand(ReceiveLocation, HighBayBin, Item."No.");
            Shortfall := MinBaseQty - OnHand - InFlight;
            if Shortfall < 0 then
                Shortfall := 0;
            NetShortfall := Shortfall - HighBayOlderQty;

            if (Shortfall > 0) and (NetShortfall <= 0) then begin
                SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_HighBayOlderCovers,
                           StrSubstNo(OutcomeToHighBayTxt, HighBayBin),
                           StrSubstNo(HighBayCoversTxt, HighBayBin, G_Facts.FormatQty(HighBayOlderQty), G_Facts.FormatDate(HighBayEarliest)));
                exit;
            end;

            if (Shortfall > 0) and (NetShortfall > 0) then begin
                SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_HighBayOlderPartial,
                           StrSubstNo(OutcomeSplitTxt, FaceBin, HighBayBin),
                           StrSubstNo(HighBayPartialTxt, HighBayBin, G_Facts.FormatQty(HighBayOlderQty), G_Facts.FormatDate(HighBayEarliest),
                                      MainFaceBin, G_Facts.FormatQty(Shortfall), G_Facts.FormatQty(NetShortfall)));
                exit;
            end;
        end;

        // ---- Rule 6: face already full (checked before the Min-Qty rule,
        //      because with no room the top-up cannot happen either) ----
        if RoomAvailable <= 0 then begin
            SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_FaceFull,
                       StrSubstNo(OutcomeToHighBayTxt, HighBayBin),
                       StrSubstNo(FaceFullTxt, MainFaceBin, G_Facts.FormatQty(OnHand), G_Facts.FormatQty(MaxBaseQty), HighBayBin));
            exit;
        end;

        // ---- Rule 4: Min-Qty top-up bypass (Cod99983 step 3) ----
        if (OnHand + InFlight) < MinBaseQty then begin
            SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_BelowMinQty,
                       StrSubstNo(OutcomeSplitTxt, FaceBin, HighBayBin),
                       StrSubstNo(BelowMinTxt, MainFaceBin, G_Facts.FormatQty(OnHand), G_Facts.FormatQty(MinBaseQty),
                                  G_Facts.FormatQty(RoomAvailable), G_Facts.FormatQty(MaxBaseQty)));
            exit;
        end;

        // ---- Rule 5: expiry comparison (Cod99983 step 4) ----
        // Without an incoming line the screen states the threshold instead of
        // the verdict: anything expiring after FaceLatest goes to High Bay.
        if FaceLatest <> 0D then begin
            SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_ExpiryNewer,
                       StrSubstNo(OutcomeSplitTxt, FaceBin, HighBayBin),
                       StrSubstNo(ExpiryNewerTxt, MainFaceBin, G_Facts.FormatDate(FaceLatest), HighBayBin));
            exit;
        end;

        // ---- Rule 7: partial room -> split ----
        if InFlight > 0 then
            InFlightClause := StrSubstNo(InFlightClauseTxt, G_Facts.FormatQty(InFlight));

        SetVerdict(Buffer, Header, "Routing Explanation Rule NDPP"::PA_SplitByCapacity,
                   StrSubstNo(OutcomeSplitTxt, FaceBin, HighBayBin),
                   StrSubstNo(SplitTxt, MainFaceBin, G_Facts.FormatQty(RoomAvailable), G_Facts.FormatQty(MaxBaseQty),
                              G_Facts.FormatQty(OnHand), InFlightClause, HighBayBin));
    end;

    /// <summary>
    /// Mirrors Cod99983.HasMainWHBinContent - TRUE when the item has Bin
    /// Content on any Main-WH bin flagged for its routing type.
    /// </summary>
    local procedure HasMainBinContent(Item: Record Item; MainLocation: Code[20]): Boolean
    var
        TempBin: Record Bin temporary;
    begin
        G_Facts.FindMainBinsForItem(Item."No.", Item."Routing Type", TempBin);
        exit(not TempBin.IsEmpty());
    end;

    local procedure AddBinFacts(var Buffer: Record "Routing Explanation NDPP" temporary; Item: Record Item; MainLocation: Code[20]; ReceiveLocation: Code[20]; MainFaceBin: Code[20]; FaceBin: Code[20]; HighBayBin: Code[20])
    var
        TempBin: Record Bin temporary;
        MainFaceRoleTxt: Label 'Main WH pick face';
        ReceiveFaceRoleTxt: Label 'Receive decant face';
        HighBayRoleTxt: Label 'Receive High Bay';
    begin
        // Every Main-WH bin the item is set up in - Flowrack / Static items
        // can span several, and showing only the first would mislead.
        G_Facts.FindMainBinsForItem(Item."No.", Item."Routing Type", TempBin);
        if TempBin.FindSet() then
            repeat
                G_Facts.AddBinFact(Buffer, MainLocation, TempBin.Code, Item."No.", MainFaceRoleTxt);
            until TempBin.Next() = 0
        else
            if MainFaceBin <> '' then
                G_Facts.AddBinFact(Buffer, MainLocation, MainFaceBin, Item."No.", MainFaceRoleTxt);

        G_Facts.AddBinFact(Buffer, ReceiveLocation, FaceBin, Item."No.", ReceiveFaceRoleTxt);
        G_Facts.AddBinFact(Buffer, ReceiveLocation, HighBayBin, Item."No.", HighBayRoleTxt);
    end;

    local procedure GetHeader(var Buffer: Record "Routing Explanation NDPP" temporary; var Header: Record "Routing Explanation NDPP" temporary)
    begin
        Buffer.Reset();
        Buffer.SetRange("Row Type", Buffer."Row Type"::Header);
        if Buffer.FindFirst() then
            Header := Buffer;
        Buffer.Reset();
    end;

    local procedure SetVerdict(var Buffer: Record "Routing Explanation NDPP" temporary; var Header: Record "Routing Explanation NDPP" temporary; Rule: Enum "Routing Explanation Rule NDPP"; OutcomeText: Text; ExplanationText: Text)
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
        Buffer."Target Bin Code" := Header."Target Bin Code";
        Buffer."Overflow Bin Code" := Header."Overflow Bin Code";
        Buffer."Room Available" := Header."Room Available";
        Buffer."Evaluated At" := CurrentDateTime();
        Buffer.Modify();
        Buffer.Reset();
    end;
}
