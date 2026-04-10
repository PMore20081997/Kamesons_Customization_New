tableextension 99977 TransferHeaderExt extends "Transfer Header"
{
    fields
    {
        field(50000; "Transfer-To Zone Code"; Code[50])
        {
            DataClassification = ToBeClassified;
            TableRelation = Zone.Code where("Location Code" = field("Transfer-to Code"));
        }
        field(50001; "Replenishment Batch Name"; Code[20])
        {

        }
    }
}
