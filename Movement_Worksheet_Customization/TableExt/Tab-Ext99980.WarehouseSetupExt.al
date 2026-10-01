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
        // No. Series for the order number of Goods Out Orders sent from the
        // Tasklet Goods Out screen (Cod99978). The KNAPP shipping label barcode
        // (MDS_<order no.>-<sheet>, 16 chars) needs numbers of exactly 8 characters.
        field(99974; "Goods Out Nos."; Code[20])
        {
            Caption = 'Goods Out Nos.';
            TableRelation = "No. Series";
            DataClassification = CustomerContent;
        }
    }
}
