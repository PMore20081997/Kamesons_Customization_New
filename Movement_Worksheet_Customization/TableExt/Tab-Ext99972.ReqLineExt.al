tableextension 99972 Req_Line_Ext extends "Requisition Line"
{
    fields
    {
        field(99971; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            DataClassification = ToBeClassified;
        }
        field(99972; "Package No."; Code[50])
        {
            Caption = 'Package No.';
            DataClassification = ToBeClassified;
        }
        field(99973; "Lot Expiration Date"; Date)
        {
            Caption = 'Lot Expiration Date';
            DataClassification = ToBeClassified;
        }
        field(99974; "From Bin Code"; Code[20])
        {
            Caption = 'From Bin Code';
            DataClassification = ToBeClassified;
        }
        field(99975; "Created By Repl."; Boolean)
        {
            Caption = 'Created By Repl.';
            DataClassification = ToBeClassified;
        }
    }
}
