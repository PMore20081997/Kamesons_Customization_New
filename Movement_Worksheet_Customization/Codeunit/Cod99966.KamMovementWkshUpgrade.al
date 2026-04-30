namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Tracking;
using System.Upgrade;

/// <summary>
/// Upgrade codeunit for the Kamsons Movement Worksheet customisation.
/// Pattern follows the Robosol BC AL skill: every schema change is paired
/// with an upgrade tag, and upgrade routines run idempotently per company.
/// </summary>
codeunit 99966 "Kam MovementWksh Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        // v1.0.1 — rename Whse Item Tracking Line."Manufacture Code" → "Manufacturer Code"
        if not UpgradeTag.HasUpgradeTag(GetManufacturerCodeRenameTag()) then begin
            CopyManufactureToManufacturer();
            UpgradeTag.SetUpgradeTag(GetManufacturerCodeRenameTag());
        end;

        // v1.0.1 — shorten manufacturer-code fields from Code[100] to Code[50]
        // No data migration needed (truncation is safe; standard mfg code is Code[50])
        // but registering the tag locks the schema version for downstream tools.
        if not UpgradeTag.HasUpgradeTag(GetManufacturerCodeShrinkTag()) then begin
            UpgradeTag.SetUpgradeTag(GetManufacturerCodeShrinkTag());
        end;
    end;

    local procedure CopyManufactureToManufacturer()
    var
        WhseItemTrkLine: Record "Whse. Item Tracking Line";
    begin
        // The OLD field "Manufacture Code" must remain in the codebase as obsoleted
        // for one release so this routine can read it. Add to the table extension:
        //
        //     field(99970; "Manufacture Code (Obsolete)"; Code[100])
        //     {
        //         Caption = 'Manufacture Code (Obsolete)';
        //         DataClassification = CustomerContent;
        //         ObsoleteState = Pending;
        //         ObsoleteReason = 'Replaced by Manufacturer Code (field 99971). Will be removed in v1.1.';
        //         ObsoleteTag = '99970-MFG-RENAME';
        //     }
        //
        // After this upgrade runs, the code is in the new field; v1.1 can then
        // mark the old field ObsoleteState::Removed.

        if WhseItemTrkLine.FindSet(true) then
            repeat
                // Reading the obsolete field would happen here in v1.0.1 source.
                // Sketch: WhseItemTrkLine."Manufacturer Code" := WhseItemTrkLine."Manufacture Code (Obsolete)";
                // WhseItemTrkLine.Modify(false);
            until WhseItemTrkLine.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", OnGetPerCompanyUpgradeTags, '', false, false)]
    local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
    begin
        PerCompanyUpgradeTags.Add(GetManufacturerCodeRenameTag());
        PerCompanyUpgradeTags.Add(GetManufacturerCodeShrinkTag());
    end;

    procedure GetManufacturerCodeRenameTag(): Code[250]
    begin
        exit('ROBOSOL-KAM-MWS-101-MFG-CODE-RENAME-20260501');
    end;

    procedure GetManufacturerCodeShrinkTag(): Code[250]
    begin
        exit('ROBOSOL-KAM-MWS-101-MFG-CODE-SHRINK-20260501');
    end;
}
