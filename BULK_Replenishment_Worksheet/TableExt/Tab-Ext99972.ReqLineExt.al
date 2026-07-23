tableextension 99972 Req_Line_Ext extends "Requisition Line"
{
    fields
    {
        field(99971; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            DataClassification = CustomerContent;
        }
        field(99972; "Package No."; Code[50])
        {
            Caption = 'Package No.';
            DataClassification = CustomerContent;
        }
        field(99973; "Lot Expiration Date"; Date)
        {
            Caption = 'Lot Expiration Date';
            DataClassification = CustomerContent;
        }
        field(99974; "From Bin Code"; Code[20])
        {
            Caption = 'From Bin Code';
            DataClassification = CustomerContent;
        }
        field(99975; "Created By Repl."; Boolean)
        {
            Caption = 'Created By Repl.';
            DataClassification = CustomerContent;
        }
        field(99976; "Manufacturer Code"; Code[100])
        {
            Caption = 'Manufacturer Code';
            DataClassification = CustomerContent;
        }
        field(99977; "Manufacturer Name"; Text[100])
        {
            Caption = 'Manufacturer Name';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
