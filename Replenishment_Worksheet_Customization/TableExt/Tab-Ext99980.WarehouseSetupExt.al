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
    }
}
