tableextension 99972 Req_Line_Ext extends "Requisition Line"
{
    fields
    {
        field(50000; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            DataClassification = ToBeClassified;
        }
        field(50001; "Package No."; Code[50])
        {
            Caption = 'Package No.';
            DataClassification = ToBeClassified;
        }
        field(50002; "Lot Expiration Date"; Date)
        {
            Caption = 'Lot Expiration Date';
            DataClassification = ToBeClassified;
        }
        field(50003; "From Bin Code"; Code[20])
        {
            Caption = 'From Bin Code';
            DataClassification = ToBeClassified;
        }
        field(50004; "Created By Repl."; Boolean)
        {
            Caption = 'Created By Repl.';
            DataClassification = ToBeClassified;
        }
    }
}
