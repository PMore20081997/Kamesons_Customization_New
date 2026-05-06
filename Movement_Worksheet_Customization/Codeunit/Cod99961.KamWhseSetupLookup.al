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
    procedure GetGenDecantZone(LocationCode: Code[10]): Code[10]
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
    procedure TryGetGenDecantZone(LocationCode: Code[10]; var ZoneCode: Code[10]): Boolean
    var
        Bin: Record Bin;
    begin
        Clear(ZoneCode);
        Bin.SetRange("Location Code", LocationCode);
        Bin.SetRange(Flowrack, true);
        if Bin.FindFirst() then begin
            ZoneCode := Bin."Zone Code";
            exit(true);
        end;
        exit(false);
    end;

    procedure GetGenDecantZonefromBinContent(P_LocationCode: Code[10]; _ItemNo: Code[20]): Code[10]
    var
        L_BinContent: Record "Bin Content";
    begin
        L_BinContent.Reset();
        L_BinContent.SetRange("Location Code", P_LocationCode);
        L_BinContent.SetRange("Item No.", _ItemNo);
        if L_BinContent.FindFirst() then
            exit(L_BinContent."Zone Code");
    end;
}
