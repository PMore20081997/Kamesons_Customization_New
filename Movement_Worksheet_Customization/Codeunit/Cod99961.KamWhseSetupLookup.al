namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Setup;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Read-only helpers for the Kamsons warehouse topology.
/// Pure: no side effects, no events, no inserts.
/// All callers go through this codeunit so we have one place to fix
/// when the warehouse model changes (e.g. multi-site rollout).
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

    /// <summary>Returns the zone in the given location flagged as Bulk. Errors if not found.</summary>
    procedure GetBulkZone(LocationCode: Code[10]): Code[10]
    var
        Zone: Record Zone;
        ZoneNotFoundErr: Label 'No zone with the Bulk flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Zone.SetCurrentKey("Location Code", BULK);
        Zone.SetRange("Location Code", LocationCode);
        Zone.SetRange(BULK, true);
        if not Zone.FindFirst() then
            Error(ZoneNotFoundErr, LocationCode);
        exit(Zone.Code);
    end;

    procedure GetHighBayZone(LocationCode: Code[10]): Code[10]
    var
        Zone: Record Zone;
        ZoneNotFoundErr: Label 'No zone with the High Bay flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Zone.SetCurrentKey("Location Code", HighBay);
        Zone.SetRange("Location Code", LocationCode);
        Zone.SetRange(HighBay, true);
        if not Zone.FindFirst() then
            Error(ZoneNotFoundErr, LocationCode);
        exit(Zone.Code);
    end;

    procedure GetGenDecantZone(LocationCode: Code[10]): Code[10]
    var
        Zone: Record Zone;
        ZoneNotFoundErr: Label 'No zone with the General Decant flag was found in location %1.', Comment = '%1 = Location Code';
    begin
        Zone.SetCurrentKey("Location Code", "General");
        Zone.SetRange("Location Code", LocationCode);
        Zone.SetRange("General", true);
        if not Zone.FindFirst() then
            Error(ZoneNotFoundErr, LocationCode);
        exit(Zone.Code);
    end;

    /// <summary>
    /// Soft variant — returns empty string when no matching zone exists.
    /// Use only at decision points where "no zone" is a legitimate "skip" signal.
    /// </summary>
    procedure TryGetGenDecantZone(LocationCode: Code[10]; var ZoneCode: Code[10]): Boolean
    var
        Zone: Record Zone;
    begin
        Clear(ZoneCode);
        Zone.SetCurrentKey("Location Code", "General");
        Zone.SetRange("Location Code", LocationCode);
        Zone.SetRange("General", true);
        if Zone.FindFirst() then begin
            ZoneCode := Zone.Code;
            exit(true);
        end;
        exit(false);
    end;

    procedure GetGenDecantZonefromBinContent(P_LocationCode: Code[10]; _ItemNo: Code[20]): Code[10]
    var
        L_BinContent: Record "Bin Content";
    begin
        // L_Zone.Reset();
        // L_Zone.SetRange("Location Code", P_LocationCode);
        // L_Zone.SetFilter(L_Zone."General", '%1', true);
        // if L_Zone.FindFirst() then
        //     exit(L_Zone.Code);

        L_BinContent.Reset();
        L_BinContent.SetRange("Location Code", P_LocationCode);
        L_BinContent.SetRange("Item No.", _ItemNo);
        if L_BinContent.FindFirst() then begin
            exit(L_BinContent."Zone Code")
        end;
    end;
}
