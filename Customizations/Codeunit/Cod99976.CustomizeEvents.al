namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.Ledger;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Structure;
using Microsoft.Warehouse.Activity;
using Microsoft.Inventory.Tracking;
using Microsoft.Warehouse.History;
using Microsoft.Warehouse.Tracking;
using Microsoft.Inventory.Item.Catalog;
using Microsoft.Sales.Document;
using Microsoft.Sales.Customer;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Setup;
using Microsoft.Finance.Dimension;
using Microsoft.Finance.Currency;
using Microsoft.Inventory.Location;

codeunit 99976 Customize_Events
{
    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purchases Warehouse Mgt.", OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine, '', false, false)]
    // local procedure OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine(var WarehouseReceiptLine: Record "Warehouse Receipt Line"; PurchaseLine: Record "Purchase Line")
    // begin
    //     WarehouseReceiptLine."Manufacturer Code" := PurchaseLine."Manufacturer Code";
    // end;


    //New++
    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromPostedWhseRcptLine, '', false, false)]
    local procedure OnAfterCopyTrackingFromPostedWhseRcptLine(PostedWhseRcptLine: Record "Posted Whse. Receipt Line"; var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        L_TaskletCodeunits: Codeunit Tasklet_Codeunits;
    begin
        WarehouseActivityLine."Manufacturer Code" := PostedWhseRcptLine."Manufacturer Code";
        WarehouseActivityLine."Manufacturer Name" := CopyStr(L_TaskletCodeunits.GetManufacturerName(PostedWhseRcptLine."Manufacturer Code"), 1, MaxStrLen(WarehouseActivityLine."Manufacturer Name"));
    end;

    [EventSubscriber(ObjectType::Table, Database::"Whse. Item Entry Relation", OnAfterInitFromTrackingSpec, '', false, false)]
    local procedure OnAfterInitFromTrackingSpec(TrackingSpecification: Record "Tracking Specification"; var WhseItemEntryRelation: Record "Whse. Item Entry Relation")
    begin
        WhseItemEntryRelation."Manufacturer Code" := TrackingSpecification."Manufacturer Code";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Posted Whse. Receipt Line", OnAfterCopyTrackingFromWhseItemEntryRelation, '', false, false)]
    local procedure OnAfterCopyTrackingFromWhseItemEntryRelation(var PostedWhseReceiptLine: Record "Posted Whse. Receipt Line"; WhseItemEntryRelation: Record "Whse. Item Entry Relation")
    var
        L_TaskletCodeunits: Codeunit Tasklet_Codeunits;
    begin
        PostedWhseReceiptLine."Manufacturer Code" := WhseItemEntryRelation."Manufacturer Code";
        PostedWhseReceiptLine."Manufacturer Name" := CopyStr(L_TaskletCodeunits.GetManufacturerName(WhseItemEntryRelation."Manufacturer Code"), 1, MaxStrLen(PostedWhseReceiptLine."Manufacturer Name"));
    end;
    //New--

    // Posted Whse. Receipt Line -> Warehouse Activity Line (Put-away from Warehouse Receipt).
    // Mirrors how Lot No. / Expiration Date flow into the activity line during put-away creation.
    // [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterCopyTrackingFromPostedWhseRcptLine, '', false, false)]
    // local procedure WhseActLine_OnAfterCopyTrkgFromPostedWhseRcptLine(PostedWhseRcptLine: Record "Posted Whse. Receipt Line"; var WarehouseActivityLine: Record "Warehouse Activity Line")
    // begin
    //     WarehouseActivityLine."Manufacturer Code" := PostedWhseRcptLine."Manufacturer Code";
    // end;

    // Auto-fill Manufacturer Code from the source Purchase Line when Lot No. is
    // entered on Item Tracking Lines (Tracking Specification — used by Purchase
    // Order tracking). Source Type 39 = "Purchase Line".
    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification", OnAfterValidateEvent, 'Lot No.', false, false)]
    local procedure TrackingSpec_OnAfterValidateLotNo_AssignMfrCode(var Rec: Record "Tracking Specification")
    var
        L_PurchLine: Record "Purchase Line";
        L_PurchDocType: Enum "Purchase Document Type";
    begin
        if Rec."Lot No." = '' then
            exit;
        if Rec."Source Type" <> Database::"Purchase Line" then
            exit;

        L_PurchDocType := Enum::"Purchase Document Type".FromInteger(Rec."Source Subtype");
        if L_PurchLine.Get(L_PurchDocType, Rec."Source ID", Rec."Source Ref. No.") then
            Rec."Manufacturer Code" := L_PurchLine."Manufacturer Code";
    end;

    // Same behavior for Warehouse Item Tracking Lines (used by Warehouse Receipt).
    // Source Type 5768 = "Warehouse Receipt Line"; navigate Whse Rcpt Line ->
    // Purchase Line via its Source No. / Source Line No.
    [EventSubscriber(ObjectType::Table, Database::"Whse. Item Tracking Line", OnAfterValidateEvent, 'Lot No.', false, false)]
    local procedure WhseItemTrkgLine_OnAfterValidateLotNo_AssignMfrCode(var Rec: Record "Whse. Item Tracking Line")
    var
        L_WhseRcptLine: Record "Warehouse Receipt Line";
        L_PurchLine: Record "Purchase Line";
        L_TaskletCodeunits: Codeunit Tasklet_Codeunits;
    begin
        if Rec."Lot No." = '' then
            exit;
        if Rec."Source Type" <> Database::"Warehouse Receipt Line" then
            exit;
        if not L_WhseRcptLine.Get(Rec."Source ID", Rec."Source Ref. No.") then
            exit;
        if L_WhseRcptLine."Source Document" <> L_WhseRcptLine."Source Document"::"Purchase Order" then
            exit;
        if L_PurchLine.Get(L_PurchLine."Document Type"::Order, L_WhseRcptLine."Source No.", L_WhseRcptLine."Source Line No.") then begin
            Rec."Manufacturer Code" := L_PurchLine."Manufacturer Code";
            Rec."Manufacturer Name" := CopyStr(L_TaskletCodeunits.GetManufacturerName(Rec."Manufacturer Code"), 1, MaxStrLen(Rec."Manufacturer Name"));
        end;
    end;

    // Flow Dispensary / Retail flags from the selected Ship-to Address to the Sales Header.
    [EventSubscriber(ObjectType::Table, Database::"Sales Header", OnAfterValidateEvent, 'Ship-to Code', false, false)]
    local procedure SalesHeader_OnAfterValidateShipToCode_FlowFlags(var Rec: Record "Sales Header")
    var
        L_ShipToAddress: Record "Ship-to Address";
    begin
        if Rec."Sell-to Customer No." = '' then
            exit;
        if Rec."Ship-to Code" = '' then begin
            Rec.Dispensary := false;
            Rec."Retail " := false;
            exit;
        end;
        if L_ShipToAddress.Get(Rec."Sell-to Customer No.", Rec."Ship-to Code") then begin
            Rec.Dispensary := L_ShipToAddress.Dispensary;
            Rec."Retail " := L_ShipToAddress."Retail ";
        end;
    end;

    // Flow "Group Branches" from the selected Customer onto the Sales Header,
    // so sales lines can apply Hub-based pricing — see
    // SalesLine_OnAfterValidateNo_ApplyHubPricing below.
    [EventSubscriber(ObjectType::Table, Database::"Sales Header", OnAfterValidateEvent, 'Sell-to Customer No.', false, false)]
    local procedure SalesHeader_OnAfterValidateSellToCustomerNo_FlowGroupBranches(var Rec: Record "Sales Header")
    var
        L_Customer: Record Customer;
    begin
        if Rec."Sell-to Customer No." = '' then begin
            Rec."Group Branches" := false;
            exit;
        end;
        Rec."Group Branches" := L_Customer.Get(Rec."Sell-to Customer No.") and L_Customer."Group Branches";
    end;

    // Hub-based pricing on Order / Quote sales lines, in priority order:
    //   1. Customer flagged "Group Branches" AND the line's Location is NOT a
    //      Hub (Location."Hub" = FALSE) -> Unit Price = Unit Cost (LCY),
    //      converted to the document currency. Applies to ANY such line,
    //      independent of the "BRANCHES" dimension.
    //   2. Otherwise, only when the order carries a value on the "BRANCHES"
    //      dimension:
    //        a. Location is a Hub (Location."Hub" = TRUE) -> Unit Price =
    //           Unit Cost (LCY) + the configurable margin % from Sales &
    //           Receivables Setup, converted to the document currency.
    //        b. Location is NOT a Hub                     -> Unit Price = 0.
    //   3. None of the above -> standard pricing is left untouched.
    // Fires after the item ("No.") validation has applied the normal price.
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", OnAfterValidateEvent, 'No.', false, false)]
    local procedure SalesLine_OnAfterValidateNo_ApplyHubPricing(var Rec: Record "Sales Line")
    var
        L_SalesHeader: Record "Sales Header";
        L_Location: Record Location;
        L_IsHubLocation: Boolean;
    begin
        if Rec.Type <> Rec.Type::Item then
            exit;
        if Rec."No." = '' then
            exit;
        if not (Rec."Document Type" in [Rec."Document Type"::Order, Rec."Document Type"::Quote]) then
            exit;
        if Rec."Sell-to Customer No." = '' then
            exit;
        if not L_SalesHeader.Get(Rec."Document Type", Rec."Document No.") then
            exit;

        L_IsHubLocation := (Rec."Location Code" <> '') and L_Location.Get(Rec."Location Code") and L_Location.Hub;

        // Rule 1 — Group Branches customer at a non-Hub location: cost price,
        // unconditional on the Branches dimension.
        if L_SalesHeader."Group Branches" and not L_IsHubLocation then begin
            Rec.Validate("Unit Price", CalcConvertedCostPrice(Rec, L_SalesHeader, 0));
            exit;
        end;

        // Rules 2a/2b only apply when the order carries a Branches dimension value.
        if not HasBranchesDimension(L_SalesHeader) then
            exit;

        if L_IsHubLocation then
            Rec.Validate("Unit Price", CalcConvertedCostPrice(Rec, L_SalesHeader, GetHubSalesMarginPct()))
        else
            Rec.Validate("Unit Price", 0);
    end;

    /// <summary>
    /// TRUE when the sales header's Dimension Set ID carries a non-blank value
    /// on the "BRANCHES" dimension.
    /// </summary>
    local procedure HasBranchesDimension(SalesHeader: Record "Sales Header"): Boolean
    var
        L_DimSetEntry: Record "Dimension Set Entry";
    begin
        if SalesHeader."Dimension Set ID" = 0 then
            exit(false);
        exit(L_DimSetEntry.Get(SalesHeader."Dimension Set ID", BranchesDimensionCodeTok) and (L_DimSetEntry."Dimension Value Code" <> ''));
    end;

    local procedure GetHubSalesMarginPct(): Decimal
    var
        L_SalesSetup: Record "Sales & Receivables Setup";
    begin
        L_SalesSetup.Get();
        exit(L_SalesSetup."Hub Sales Margin %");
    end;

    /// <summary>
    /// Unit Cost (LCY) plus MarginPct (0 for an exact cost price), converted
    /// from LCY to the sales document's currency using the Currency Factor
    /// already stored on the header (set when its Currency Code / Posting Date
    /// were resolved) — no re-lookup of the exchange rate here. Rounds to the
    /// currency's (or, for LCY, General Ledger Setup's) Unit-Amount Rounding
    /// Precision, matching the precision a Unit Price field is expected to carry.
    /// </summary>
    local procedure CalcConvertedCostPrice(SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header"; MarginPct: Decimal): Decimal
    var
        L_Currency: Record Currency;
        L_UnitPriceLCY: Decimal;
        L_UnitPriceFCY: Decimal;
    begin
        L_UnitPriceLCY := SalesLine."Unit Cost (LCY)" * (1 + (MarginPct / 100));

        if SalesHeader."Currency Code" = '' then begin
            L_Currency.InitRoundingPrecision();
            exit(Round(L_UnitPriceLCY, L_Currency."Unit-Amount Rounding Precision"));
        end;

        L_Currency.Get(SalesHeader."Currency Code");
        // Standard BC convention: "Currency Factor" converts FCY -> LCY by
        // division (AmountLCY = AmountFCY / Factor); the inverse LCY -> FCY is
        // therefore multiplication. A blank/zero factor (header currency not
        // yet resolved) is treated as 1:1 defensively.
        if SalesHeader."Currency Factor" = 0 then
            L_UnitPriceFCY := L_UnitPriceLCY
        else
            L_UnitPriceFCY := L_UnitPriceLCY * SalesHeader."Currency Factor";
        exit(Round(L_UnitPriceFCY, L_Currency."Unit-Amount Rounding Precision"));
    end;







    // Restrict Main Warehouse to a single Item / Location / Zone / Bin combination.
    // Why: business rule — one item must live in exactly one bin at the Main location.
    // [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeInsertEvent, '', false, false)]
    // local procedure BinContent_OnBeforeInsert_RestrictOneBinPerItem(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    // var
    //     L_ExistingBinContent: Record "Bin Content";
    //     L_MainLocation: Code[20];
    // begin
    //     if Rec.IsTemporary() then
    //         exit;
    //     if Rec."Item No." = '' then
    //         exit;

    //     L_MainLocation := G_Events.GetMainWarehouse();
    //     if L_MainLocation = '' then
    //         exit;
    //     if Rec."Location Code" <> L_MainLocation then
    //         exit;

    //     L_ExistingBinContent.SetRange("Location Code", Rec."Location Code");
    //     L_ExistingBinContent.SetRange("Item No.", Rec."Item No.");
    //     //L_ExistingBinContent.SetRange("Variant Code", Rec."Variant Code");
    //     L_ExistingBinContent.SetFilter("Bin Code", '<>%1', Rec."Bin Code");
    //     if not L_ExistingBinContent.IsEmpty() then begin
    //         L_ExistingBinContent.FindFirst();
    //         Error('Item %1 already exists at Main Location %2 in Zone %3 / Bin %4. Only one Item/Location/Zone/Bin combination is allowed.',
    //             Rec."Item No.", Rec."Location Code", L_ExistingBinContent."Zone Code", L_ExistingBinContent."Bin Code");
    //     end;
    // end;

    // (1) Force Max. Qty. := 0 when the row's Bin is flagged Flowrack.
    //     Flowrack faces are sized by tote count (Number of Totes in a Bin),
    //     not by a base-unit Max Qty, so any value > 0 here is misleading.
    // [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeInsertEvent, '', false, false)]
    // local procedure BinContent_OnBeforeInsert_ForceFlowrackMaxQty(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    // begin
    //     if Rec.IsTemporary() then
    //         exit;
    //     if IsFlowrackBin(Rec."Location Code", Rec."Bin Code") then
    //         Rec."Max. Qty." := 0;
    // end;

    // [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeModifyEvent, '', false, false)]
    // local procedure BinContent_OnBeforeModify_ForceFlowrackMaxQty(var Rec: Record "Bin Content"; var xRec: Record "Bin Content"; RunTrigger: Boolean)
    // begin
    //     if Rec.IsTemporary() then
    //         exit;
    //     if IsFlowrackBin(Rec."Location Code", Rec."Bin Code") then
    //         Rec."Max. Qty." := 0;
    // end;

    // (2) For BULK items, enforce the bin-flag layout at Main and Receive locations.
    //
    //     A BULK item is allowed exactly two kinds of Bin Content per location:
    //       * ONE Bulk-flagged bin    — its decant face, resolved by GetItemBulkBinCode
    //       * ONE HighBay-flagged bin — the overflow buffer the put-away engine
    //                                   spills into (cod 99983 HandleBinCapacity)
    //     Static- and Flowrack-flagged bins are never valid for a BULK item, and an
    //     unflagged bin is not a routing destination at all.
    //
    //     The test is on the BIN'S FLAGS, not on the bin code: two different bin
    //     codes are fine when one is Bulk and the other HighBay, while a second
    //     Bulk-flagged bin is rejected however it is named.
    [EventSubscriber(ObjectType::Table, Database::"Bin Content", OnBeforeInsertEvent, '', false, false)]
    local procedure BinContent_OnBeforeInsert_RestrictOneBinPerBulkItem(var Rec: Record "Bin Content"; RunTrigger: Boolean)
    var
        L_Item: Record Item;
        L_ExistingBinContent: Record "Bin Content";
        L_IncomingBin: Record Bin;
        L_MainLocation: Code[20];
        L_ReceiveLocation: Code[20];
        WrongFlagErr: Label 'Item %1 has Routing Type BULK, so it cannot be assigned to Bin %2 at Location %3, which is flagged as %4. A BULK item may only use a Bulk bin and a High Bay bin.', Comment = '%1 = Item No., %2 = Bin Code, %3 = Location Code, %4 = flag name';
        NoFlagErr: Label 'Bin %1 at Location %2 has no routing flag set. Set Bulk or High Bay on the bin before assigning BULK item %3 to it.', Comment = '%1 = Bin Code, %2 = Location Code, %3 = Item No.';
        DuplicateBulkErr: Label 'Item %1 (BULK) already has a Bulk bin at Location %2: Bin %3 / Zone %4. A BULK item can occupy only one Bulk Bin per Location.', Comment = '%1 = Item No., %2 = Location Code, %3 = Bin Code, %4 = Zone Code';
        DuplicateHighBayErr: Label 'Item %1 (BULK) already has a High Bay bin at Location %2: Bin %3 / Zone %4. A BULK item can occupy only one High Bay Bin per Location.', Comment = '%1 = Item No., %2 = Location Code, %3 = Bin Code, %4 = Zone Code';
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Item No." = '' then
            exit;

        L_MainLocation := G_KamWhseSetupLookup.GetMainLocation();
        L_ReceiveLocation := G_KamWhseSetupLookup.GetReceiveLocation();
        if (Rec."Location Code" <> L_MainLocation) and (Rec."Location Code" <> L_ReceiveLocation) then
            exit;

        if not L_Item.Get(Rec."Item No.") then
            exit;
        if L_Item."Routing Type" <> L_Item."Routing Type"::BULK then
            exit;

        if Rec."Bin Code" = '' then
            exit;
        if not L_IncomingBin.Get(Rec."Location Code", Rec."Bin Code") then
            exit;

        // 1. The incoming bin must be flagged Bulk or HighBay — nothing else.
        if L_IncomingBin."Static" then
            Error(WrongFlagErr, Rec."Item No.", Rec."Bin Code", Rec."Location Code", L_IncomingBin.FieldCaption("Static"));
        if L_IncomingBin.Flowrack then
            Error(WrongFlagErr, Rec."Item No.", Rec."Bin Code", Rec."Location Code", L_IncomingBin.FieldCaption(Flowrack));
        if (not L_IncomingBin.Bulk) and (not L_IncomingBin.HighBay) then
            Error(NoFlagErr, Rec."Bin Code", Rec."Location Code", Rec."Item No.");

        // 2. Only one bin of that kind per location. A Bulk row and a HighBay row
        //    coexist happily; a second row of the SAME flag is the error.
        L_ExistingBinContent.SetRange("Location Code", Rec."Location Code");
        L_ExistingBinContent.SetRange("Item No.", Rec."Item No.");
        L_ExistingBinContent.SetFilter("Bin Code", '<>%1', Rec."Bin Code");
        if L_ExistingBinContent.FindSet() then
            repeat
                if L_IncomingBin.Bulk and IsBinFlagged(L_ExistingBinContent."Location Code", L_ExistingBinContent."Bin Code", BinFlag::Bulk) then
                    Error(DuplicateBulkErr, Rec."Item No.", Rec."Location Code", L_ExistingBinContent."Bin Code", L_ExistingBinContent."Zone Code");
                // if L_IncomingBin.HighBay and IsBinFlagged(L_ExistingBinContent."Location Code", L_ExistingBinContent."Bin Code", BinFlag::HighBay) then
                //     Error(DuplicateHighBayErr, Rec."Item No.", Rec."Location Code", L_ExistingBinContent."Bin Code", L_ExistingBinContent."Zone Code");
            until L_ExistingBinContent.Next() = 0;
    end;

    /// <summary>
    /// TRUE when the given Location + Bin carries the requested routing flag.
    /// Reads the Bin directly — the matching Bin Content fields (Tab-Ext 99991,
    /// 99981..99984) are FlowField lookups onto these same Bin fields.
    /// </summary>
    /// <remarks>Flag values are passed as BinFlag::&lt;name&gt; from the global option.</remarks>
    local procedure IsBinFlagged(LocationCode: Code[10]; BinCode: Code[20]; Flag: Option Bulk,"Static",Flowrack,HighBay): Boolean
    var
        L_Bin: Record Bin;
    begin
        if BinCode = '' then
            exit(false);
        if not L_Bin.Get(LocationCode, BinCode) then
            exit(false);
        case Flag of
            BinFlag::Bulk:
                exit(L_Bin.Bulk);
            BinFlag::"Static":
                exit(L_Bin."Static");
            BinFlag::Flowrack:
                exit(L_Bin.Flowrack);
            BinFlag::HighBay:
                exit(L_Bin.HighBay);
        end;
        exit(false);
    end;

    /// <summary>
    /// TRUE if the given Location + Bin combination has the Flowrack flag set
    /// on the Bin record (PutAwayCustomization Tab-Ext99956 field "Flowrack").
    /// </summary>
    // local procedure IsFlowrackBin(LocationCode: Code[10]; BinCode: Code[20]): Boolean
    // var
    //     L_Bin: Record Bin;
    // begin
    //     if (LocationCode = '') or (BinCode = '') then
    //         exit(false);
    //     if not L_Bin.Get(LocationCode, BinCode) then
    //         exit(false);
    //     exit(L_Bin.Flowrack);
    // end;

    var
        G_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
        BranchesDimensionCodeTok: Label 'BRANCHES', Locked = true;
        // Routing flags as carried on the Bin (Tab-Ext 99956, fields 99981..99984)
        // and mirrored onto Bin Content as FlowFields (Tab-Ext 99991).
        BinFlag: Option Bulk,"Static",Flowrack,HighBay;
}
