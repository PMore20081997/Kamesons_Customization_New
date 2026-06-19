namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Location;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Item.Catalog;

// -------------------------------------------------------------------------------------
// Package Content screen on Tasklet Mobile WMS — display-only "Lookup" pattern.
//
//   Lookup page  (PackageContent)  -> shows one row per Item / Bin / Lot / Package /
//                                     Expiration Date, summed from Warehouse Entries,
//                                     filtered by Location Code and (optional) Item No.
//
// This mirrors the standard "Bin Content" screen but with the two requested filters
// (Location Code, Item No.) and the per-package/per-lot row layout shown on the device
// (Item, Description, UoM, Lot No., Package No., Exp. Date, Quantity).
//
// Data source: Query 99972 "WarehouseEntryReceive" — the same query that backs the
// "Bin Content Details" factbox (Pag99972), so the rows match what users already see in BC.
//
// IMPORTANT: This codeunit uses Tasklet's built-in Lookup document type. The screen is
// read-only — no registration steps or posting are wired (per the display-only scope).
// Header config key:  'PackageContentHeader'  (matches application.cfg page "PackageContent").
// Lookup type:        'PackageContent'        (matches lookupConfiguration type).
// -------------------------------------------------------------------------------------

codeunit 99953 "Package Content Tasklet"
{
    Access = Public;

    var
        SetupLookup: Codeunit "Kam Whse Setup Lookup";

    // ---------- 1. Header configuration: Location Code + Item No. ------------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Reference Data", 'OnGetReferenceData_OnAddHeaderConfigurations', '', true, true)]
    local procedure OnAddHeaderConfigurations_PackageContent(var _HeaderFields: Record "MOB HeaderField Element")
    var
        ReceiveLocation: Code[20];
        L_ListValues: Text;
    begin
        L_ListValues := BuildLocationCodeListValues();

        _HeaderFields.InitConfigurationKey('PackageContentHeader');

        // Location Code — shown as a dropdown of available locations.
        // Default = Receive Location from Warehouse Setup (guarded with TryFunction
        // so a missing Warehouse Setup never drops this page from the device menu).
        if TryGetReceiveLocation(ReceiveLocation) then;  // ignore error; ReceiveLocation stays '' on failure
        if L_ListValues <> '' then
            _HeaderFields.Create_ListFieldFromListValues(1, 'LocationCode', 'Location Code:', L_ListValues, ReceiveLocation)
        else begin
            _HeaderFields.Create_TextField(1, 'LocationCode', 'Location Code:');
            if ReceiveLocation <> '' then
                _HeaderFields.Set_DefaultValue(ReceiveLocation);
        end;

        // Item No. — optional; operator can leave blank to see all items at the location.
        _HeaderFields.Create_TextField(2, 'ItemNo', 'Item:');
        _HeaderFields.Set_optional(true);

        _HeaderFields.Create_TextField(3, 'PackageNo', 'Package No.:');
        _HeaderFields.Set_optional(true);
    end;

    local procedure BuildLocationCodeListValues(): Text
    var
        L_ListValues: Text;
    begin

        L_ListValues += ';' + SetupLookup.GetReceiveLocation();
        L_ListValues += ';' + SetupLookup.GetMainLocation();


        exit(DelChr(L_ListValues, '<', ';'));  // strip leading separators
    end;

    [TryFunction]
    local procedure TryGetReceiveLocation(var ReceiveLocation: Code[20])
    begin
        ReceiveLocation := SetupLookup.GetReceiveLocation();
    end;

    // ---------- 2. Lookup: list package content for the chosen filters -------

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MOB WMS Lookup", 'OnLookupOnCustomLookupType', '', true, true)]
    local procedure OnLookupOnCustomLookupType_PackageContent(_MessageId: Guid; _LookupType: Text; var _RequestValues: Record "MOB NS Request Element"; var _LookupResponseElement: Record "MOB NS WhseInquery Element"; var _RegistrationTypeTracking: Text; var _IsHandled: Boolean)
    var
        WhseEntryQuery: Query WarehouseEntryReceive;
        ItemDescription: Text;
        LocationFilter: Text;
        ItemFilter: Text;
        PackageNoFilter: Text;
    begin
        if _IsHandled then
            exit;
        if _LookupType <> 'PackageContent' then
            exit;

        LocationFilter := _RequestValues.GetValue('LocationCode');
        ItemFilter := _RequestValues.GetValue('ItemNo', false);
        ItemFilter := ResolveItemNoFromScan(ItemFilter);
        PackageNoFilter := _RequestValues.GetValue('PackageNo', false);

        if LocationFilter <> '' then
            WhseEntryQuery.SetFilter(Location_Code, LocationFilter);
        if ItemFilter <> '' then
            WhseEntryQuery.SetFilter(Item_No_, ItemFilter);
        if PackageNoFilter <> '' then
            WhseEntryQuery.SetFilter(Package_No_, PackageNoFilter);
        // Only show positive on-hand quantities (mirrors the Bin Content Details factbox).
        WhseEntryQuery.SetFilter(Qty_Base, '>%1', 0);
        WhseEntryQuery.Open();

        while WhseEntryQuery.Read() do begin
            _LookupResponseElement.Create();

            ItemDescription := GetItemDescription(CopyStr(WhseEntryQuery.Item_No_, 1, 20));

            // Line 1 (headline): Item No. + Bin Code (matches "W00488 ... SRN-01-E1" context).
            _LookupResponseElement.Set_DisplayLine1(WhseEntryQuery.Item_No_ + '  ' + WhseEntryQuery.Bin_Code);
            // Line 2: Description.
            _LookupResponseElement.Set_DisplayLine2(ItemDescription);
            // Line 3: UoM.
            //_LookupResponseElement.Set_DisplayLine3('UoM: ' + WhseEntryQuery.Unit_of_Measure_Code);
            // Line 4: Lot No. / Package No. / Exp. Date (as on the device screenshot).
            _LookupResponseElement.Set_DisplayLine3(BuildTrackingLine(WhseEntryQuery));

            // Right-hand column: Quantity (and UoM in the registrations list slot).
            _LookupResponseElement.Set_Quantity(Format(WhseEntryQuery.Qty_Base));
            _LookupResponseElement.Set_ExtraInfo1(WhseEntryQuery.Unit_of_Measure_Code);
        end;

        WhseEntryQuery.Close();

        _IsHandled := true;
    end;

    // ---------- Helpers ------------------------------------------------------

    local procedure GetItemDescription(ItemNo: Code[20]): Text
    var
        Item: Record Item;
    begin
        if ItemNo = '' then
            exit('');
        if Item.Get(ItemNo) then
            exit(Item.Description);
        exit('');
    end;

    local procedure ResolveItemNoFromScan(ScannedValue: Text): Text
    var
        ItemReference: Record "Item Reference";
        Barcode: Code[50];
    begin
        if ScannedValue = '' then
            exit('');

        Barcode := CopyStr(ScannedValue, 1, MaxStrLen(Barcode));
        ItemReference.SetRange("Reference Type", ItemReference."Reference Type"::"Bar Code");
        ItemReference.SetRange("Reference No.", Barcode);
        if ItemReference.FindFirst() then
            exit(ItemReference."Item No.");

        exit(ScannedValue);
    end;

    local procedure BuildTrackingLine(var WhseEntryQuery: Query WarehouseEntryReceive): Text
    var
        Result: Text;
    begin
        if WhseEntryQuery.Lot_No_ <> '' then
            Result := 'Lot No.: ' + WhseEntryQuery.Lot_No_;
        if WhseEntryQuery.Package_No_ <> '' then begin
            if Result <> '' then
                Result += '  ';
            Result += 'Package No.: ' + WhseEntryQuery.Package_No_;
        end;
        if WhseEntryQuery.Expiration_Date <> 0D then begin
            if Result <> '' then
                Result += '  ';
            Result += 'Exp. Date: ' + Format(WhseEntryQuery.Expiration_Date);
        end;
        exit(Result);
    end;
}
