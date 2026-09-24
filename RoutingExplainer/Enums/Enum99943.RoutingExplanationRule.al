namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// The specific rule that decided an outcome, across all three explained
/// processes. Values are grouped by process so new rules can be appended
/// within a block without renumbering.
///
/// IMPORTANT — these values MIRROR the live engines. When a rule changes in
/// any of the three engines below, the matching explainer codeunit AND this
/// enum must be updated to match. The engines are deliberately NOT modified
/// to report their own reasons (see Cod99942 header for the rationale).
///
///   10..19  Put-Away      — codeunit 99983 "Put-Away Mgt. NDPP"
///   20..29  Bulk Replen   — report 99971 "Cal _Bin Replenishment New"
///   30..39  Decant        — codeunit 99991 "Create Decant Whse Reclass And Post"
/// </summary>
enum 99943 "Routing Explanation Rule NDPP"
{
    Extensible = true;
    Caption = 'Rule Applied';

    value(0; "None")
    {
        Caption = ' ';
    }

    // ---------- Put-Away (mirrors Cod99983.RoutePutAwayLine) ----------
    value(10; "PA_NoMasterData")
    {
        Caption = 'No Main Warehouse bin set up for this item';
    }
    value(11; "PA_HighBayOlderCovers")
    {
        Caption = 'Older stock in High Bay must be used first';
    }
    value(12; "PA_HighBayOlderPartial")
    {
        Caption = 'Older High Bay stock only partly covers the shortfall';
    }
    value(13; "PA_BelowMinQty")
    {
        Caption = 'Decant face below minimum - topped up';
    }
    value(14; "PA_ExpiryNewer")
    {
        Caption = 'Incoming stock is newer than the decant face';
    }
    value(15; "PA_FaceFull")
    {
        Caption = 'Decant face already at maximum';
    }
    value(16; "PA_SplitByCapacity")
    {
        Caption = 'Split - decant face had only partial room';
    }
    value(17; "PA_FitsInFace")
    {
        Caption = 'Fitted in the available space on the decant face';
    }

    // ---------- Bulk Replenishment (mirrors Rep99971) ----------
    value(20; "BR_NotBulkItem")
    {
        Caption = 'Item is not a BULK routing type';
    }
    value(21; "BR_NoBulkBinContent")
    {
        Caption = 'No BULK bin set up for this item in the Main Warehouse';
    }
    value(22; "BR_AboveMinQty")
    {
        Caption = 'Bin is above its minimum quantity';
    }
    value(23; "BR_CoveredByTransferOrder")
    {
        Caption = 'Open Transfer Orders already cover the shortfall';
    }
    value(24; "BR_NoSourceStock")
    {
        Caption = 'No usable source stock in the Receive BULK bin';
    }
    value(25; "BR_AlreadyOnWorksheet")
    {
        Caption = 'A worksheet line already exists for this stock';
    }
    value(26; "BR_WouldReplenish")
    {
        Caption = 'Replenishment would be created';
    }

    // ---------- Decant (mirrors Cod99991) ----------
    value(30; "DC_NotDecantItem")
    {
        Caption = 'Item is not a Flowrack or Static routing type';
    }
    value(31; "DC_NoDestinationBin")
    {
        Caption = 'No matching destination bin in the Main Warehouse';
    }
    value(32; "DC_NoQtyPerTote")
    {
        Caption = 'No Qty per Tote set up for this item and manufacturer';
    }
    value(33; "DC_NoEmptyTotes")
    {
        Caption = 'Destination bin has no empty totes';
    }
    value(34; "DC_NoSourceStock")
    {
        Caption = 'No usable source stock in the Receive bins';
    }
    value(35; "DC_LimitedByTotes")
    {
        Caption = 'Limited by the number of empty totes';
    }
    value(36; "DC_LimitedBySource")
    {
        Caption = 'Limited by the stock available to take';
    }
}
