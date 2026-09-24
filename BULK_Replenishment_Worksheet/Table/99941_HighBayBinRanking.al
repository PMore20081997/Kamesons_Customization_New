namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// TEMPORARY ranking buffer used by report 99971 "Cal _Bin Replenishment New"
/// to order the Receive location's HIGHBAY bins by the earliest usable expiry
/// each one holds for an item.
///
/// Exists so the report can drain HighBay oldest-stock-first across SEVERAL
/// bins. Without an explicit ranking the bins would be visited in bin-code
/// order, which could send newer stock to the pick face while an older lot sat
/// in another bin until it expired.
///
/// Always used as `temporary` - nothing is ever persisted, and the table has no
/// permissions entry or UI of its own.
/// </summary>
table 99941 "HighBay Bin Ranking NDPP"
{
    Caption = 'HighBay Bin Ranking';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Earliest Expiry"; Date)
        {
            Caption = 'Earliest Expiry';
            DataClassification = SystemMetadata;
        }
        field(2; "Bin Code"; Code[20])
        {
            Caption = 'Bin Code';
            DataClassification = SystemMetadata;
        }
        field(3; "Location Code"; Code[20])
        {
            Caption = 'Location Code';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        /// Expiry first so a plain FindSet walks the bins oldest-stock-first.
        /// Bin Code is part of the key only to keep entries unique when two
        /// bins share an earliest expiry.
        key(PK; "Earliest Expiry", "Bin Code")
        {
            Clustered = true;
        }
    }
}
