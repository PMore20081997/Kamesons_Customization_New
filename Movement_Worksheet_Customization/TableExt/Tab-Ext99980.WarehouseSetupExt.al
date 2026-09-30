tableextension 99980 WarehouseSetupExt extends "Warehouse Setup"
{
    fields
    {
        field(99971; "MAIN Warehouse"; Code[20])
        {
            Caption = 'MAIN Warehouse';
            TableRelation = Location.Code;
            DataClassification = CustomerContent;
        }
        field(99972; "RECEIVE Warehouse"; Code[20])
        {
            Caption = 'RECEIVE Warehouse';
            TableRelation = Location.Code;
            DataClassification = CustomerContent;
        }
        // No. Series for the Load Unit of BULK orders ("BULK Load Unit Details").
        // Load Unit is Code[8], so the series must produce numbers of max 8 chars.
        field(99973; "Case Label Nos."; Code[20])
        {
            Caption = 'Case Label Nos.';
            TableRelation = "No. Series";
            DataClassification = CustomerContent;
        }
    }
}
