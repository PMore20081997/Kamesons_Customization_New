tableextension 99977 TransferHeaderExt extends "Transfer Header"
{
    fields
    {
        field(99971; "Transfer-To Zone Code"; Code[50])
        {
            Caption = 'Transfer-To Zone Code';
            DataClassification = CustomerContent;
            TableRelation = Zone.Code where("Location Code" = field("Transfer-to Code"));
        }
        field(99972; "Replenishment Batch Name"; Code[20])
        {
            Caption = 'Replenishment Batch Name';
            DataClassification = CustomerContent;
        }
    }
}
