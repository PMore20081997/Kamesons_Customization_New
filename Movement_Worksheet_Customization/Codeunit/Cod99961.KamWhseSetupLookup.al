namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Setup;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Read-only helpers for the Kamsons warehouse topology.
/// Pure: no side effects, no events, no inserts.
/// All callers go through this codeunit so we have one place to fix
/// when the warehouse model changes (e.g. multi-site rollout).
///
/// Routing booleans now live on Bin (Bulk / Static / Flowrack / HighBay)
/// rather than on Zone. Zone helpers are kept as backwards-compatible
/// wrappers that resolve via the matching bin's "Zone Code".
/// </summary>
codeunit 99961 "Kam Whse Setup Lookup"
{
    Access = Public;

    procedure GetMainLocation(): Code[20]
    var
        WhseSetup: Record "Warehouse Setup";
    begin
        WhseSetup.Get();
        WhseSetup.TestField("MAIN Warehouse");
        exit(WhseSetup."MAIN Warehouse");
    end;

    procedure GetReceiveLocation(): Code[20]
    var
        WhseSetup: Record "Warehouse Setup";
    begin
        WhseSetup.Get();
        WhseSetup.TestField("RECEIVE Warehouse");
        exit(WhseSetup."RECEIVE Warehouse");
    end;

    // ---------- Item routing types (derived from Bin Content) ----------

    /// <summary>
    /// The routing types an item actually has, derived from the Main-WH bins it
    /// holds Bin Content in. Replaces the former Item."Routing Type" field.
    ///
    /// An item may be several types at once (a BULK reserve pallet AND a
    /// Flowrack pick face), which the single enum field could not represent —
    /// it silently reported only the first, so the second type's capacity was
    /// never considered.
    ///
    /// Returned in the configured Put-Away fill order (see GetRoutingPriority),
    /// so callers that must pick ONE destination can simply take the first
    /// entry with capacity. An item with no routing bins returns an empty list,
    /// which callers treat as "unconfigured" and route to High Bay.
    /// </summary>
    procedure GetItemRoutingTypes(ItemNo: Code[20]): List of [Enum "Item Routing Type NDPP"]
    begin
        exit(GetItemRoutingTypesAtLocation(ItemNo, GetMainLocation()));
    end;

    procedure GetItemRoutingTypesAtLocation(ItemNo: Code[20]; LocationCode: Code[20]): List of [Enum "Item Routing Type NDPP"]
    var
        RoutingType: Enum "Item Routing Type NDPP";
        Result: List of [Enum "Item Routing Type NDPP"];
    begin
        foreach RoutingType in GetRoutingPriority() do
            if HasBinContentOfType(ItemNo, LocationCode, RoutingType) then
                Result.Add(RoutingType);
        exit(Result);
    end;

    /// <summary>
    /// TRUE when the item holds Bin Content in at least one bin of the given
    /// routing type at the location. Filters Bin first (indexed) and then probes
    /// Bin Content, rather than filtering Bin Content's FlowField flags, which
    /// have no index and would force a scan-plus-join per row.
    /// </summary>
    procedure HasBinContentOfType(ItemNo: Code[20]; LocationCode: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Boolean
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
    begin
        if ItemNo = '' then
            exit(false);

        Bin.SetRange("Location Code", LocationCode);
        case RoutingType of
            RoutingType::BULK:
                Bin.SetRange(Bulk, true);
            RoutingType::"Static":
                Bin.SetRange("Static", true);
            RoutingType::Flowrack:
                Bin.SetRange(Flowrack, true);
            else
                exit(false);
        end;
        if not Bin.FindSet() then
            exit(false);

        repeat
            BinContent.Reset();
            BinContent.SetRange("Location Code", LocationCode);
            BinContent.SetRange("Bin Code", Bin.Code);
            BinContent.SetRange("Item No.", ItemNo);
            if not BinContent.IsEmpty() then
                exit(true);
        until Bin.Next() = 0;

        exit(false);
    end;

    /// <summary>
    /// TRUE when the item has a Main-WH bin of the given routing type.
    /// Convenience wrapper for the many callers that only need a yes/no on one
    /// type and shouldn't have to resolve the Main location themselves.
    /// </summary>
    procedure ItemHasRoutingType(ItemNo: Code[20]; RoutingType: Enum "Item Routing Type NDPP"): Boolean
    begin
        exit(HasBinContentOfType(ItemNo, GetMainLocation(), RoutingType));
    end;

    /// <summary>
    /// The Put-Away fill order, from Warehouse Setup. Falls back to
    /// BULK → Static → Flowrack when setup is blank or misconfigured, so the
    /// engine never depends on setup having been filled in.
    ///
    /// A type named twice in setup appears once here; a type omitted from setup
    /// is appended, so the list always covers all three and never routes an
    /// item's stock nowhere because of a setup slip.
    /// </summary>
    procedure GetRoutingPriority(): List of [Enum "Item Routing Type NDPP"]
    var
        WhseSetup: Record "Warehouse Setup";
        RoutingType: Enum "Item Routing Type NDPP";
        Result: List of [Enum "Item Routing Type NDPP"];
    begin
        if WhseSetup.Get() then begin
            AddDistinct(Result, WhseSetup."Routing Priority 1");
            AddDistinct(Result, WhseSetup."Routing Priority 2");
            AddDistinct(Result, WhseSetup."Routing Priority 3");
        end;

        // Backfill anything setup didn't name, in the documented default order.
        AddDistinct(Result, RoutingType::BULK);
        AddDistinct(Result, RoutingType::"Static");
        AddDistinct(Result, RoutingType::Flowrack);

        exit(Result);
    end;

    local procedure AddDistinct(var Types: List of [Enum "Item Routing Type NDPP"]; RoutingType: Enum "Item Routing Type NDPP")
    begin
        if not Types.Contains(RoutingType) then
            Types.Add(RoutingType);
    end;

    // ---------- Bin finders (primary API) ----------

    /// <summary>Returns the Bin Code in the given location flagged as Bulk. Errors if not found.</summary>
    procedure GetBulkBin(LocationCode: Code[10]): Code[20]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the Bulk flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(Bulk, true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin.Code);
    end;

    /// <summary>Returns the Bin Code in the given location flagged as Static. Errors if not found.</summary>
    procedure GetStaticBin(LocationCode: Code[10]): Code[20]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the Static flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange("Static", true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin.Code);
    end;

    /// <summary>Returns the Bin Code in the given location flagged as Flowrack (was GEN DECANT). Errors if not found.</summary>
    procedure GetFlowrackBin(LocationCode: Code[10]): Code[20]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the Flowrack flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(Flowrack, true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin.Code);
    end;

    /// <summary>Returns the Bin Code in the given location flagged as High Bay. Errors if not found.</summary>
    procedure GetHighBayBin(LocationCode: Code[10]): Code[20]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the High Bay flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(HighBay, true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin.Code);
    end;

    // ---------- Zone helpers (resolved from the matching Bin) ----------

    /// <summary>Returns the Zone Code of the Bulk-flagged bin. Errors if not found.</summary>
    procedure GetBulkZone(LocationCode: Code[10]): Code[10]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the Bulk flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(Bulk, true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin."Zone Code");
    end;

    /// <summary>Returns the Zone Code of the Static-flagged bin. Errors if not found.</summary>
    procedure GetStaticZone(LocationCode: Code[10]): Code[10]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the Static flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange("Static", true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin."Zone Code");
    end;

    /// <summary>Returns the Zone Code of the High Bay-flagged bin. Errors if not found.</summary>
    procedure GetHighBayZone(LocationCode: Code[10]): Code[10]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the High Bay flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(HighBay, true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin."Zone Code");
    end;

    /// <summary>
    /// Returns the Zone Code of the Flowrack-flagged bin (was "General Decant" zone).
    /// </summary>
    procedure GetReceiveFlowrackZone(LocationCode: Code[10]): Code[10]
    var
        Bin: Record Bin;
        BinNotFoundErr: Label 'No bin with the Flowrack flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(Flowrack, true);
        if not Bin.FindFirst() then
            Error(BinNotFoundErr, LocationCode);
        exit(Bin."Zone Code");
    end;

    /// <summary>
    /// Soft variant — returns false when no Flowrack bin exists.
    /// Use only at decision points where "no zone" is a legitimate "skip" signal.
    /// </summary>
    // procedure TryGetGenDecantZone(LocationCode: Code[10]; var ZoneCode: Code[10]): Boolean
    // var
    //     Bin: Record Bin;
    // begin
    //     Clear(ZoneCode);
    //     Bin.SetRange("Location Code", LocationCode);
    //     Bin.SetRange(Flowrack, true);
    //     if Bin.FindFirst() then begin
    //         ZoneCode := Bin."Zone Code";
    //         exit(true);
    //     end;
    //     exit(false);
    // end;

    procedure GetMainFlowrackZone(P_LocationCode: Code[10]; _ItemNo: Code[20]): Code[10]
    var
        L_Bin: Record Bin;
    begin
        L_Bin.SetRange("Location Code", P_LocationCode);
        L_Bin.SetRange(Flowrack, true);
        if L_Bin.FindFirst() then
            exit(L_Bin."Zone Code");

        exit('');
    end;
}
