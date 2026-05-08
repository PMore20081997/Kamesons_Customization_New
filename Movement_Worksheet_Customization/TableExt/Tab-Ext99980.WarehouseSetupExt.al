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
    }
}
