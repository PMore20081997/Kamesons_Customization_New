tableextension 99980 WarehouseSetupExt extends "Warehouse Setup"
{
    fields
    {
        field(50000; "MAIN Warehouse"; Code[20])
        {
            Caption = 'MAIN Warehouse';
            TableRelation = Location.Code;
            DataClassification = ToBeClassified;
        }
        field(50001; "RECEIVE Warehouse"; Code[20])
        {
            Caption = 'RECEIVE Warehouse';
            TableRelation = Location.Code;
            DataClassification = ToBeClassified;
        }
    }
}
