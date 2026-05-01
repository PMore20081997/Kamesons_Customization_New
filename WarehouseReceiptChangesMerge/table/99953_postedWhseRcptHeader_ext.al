// Mirror of Warehousereceiptheaderext (99950) on the Posted Whse. Receipt
// Header. Field IDs match so codeunit "Whse.-Post Receipt" carries the values
// automatically via TransferFields(WarehouseReceiptHeader).
tableextension 99953 "PostedWhseRcptHeaderExt" extends "Posted Whse. Receipt Header"
{
    fields
    {
        field(99950; "Transportation Arranged By"; Code[20]) { }
        field(99951; "Preferred Delivery Date"; Date) { DataClassification = ToBeClassified; }
        field(99952; "Confirmed Delivery Date"; Date) { DataClassification = ToBeClassified; }
        field(99953; "Confirmed Delivery Time"; Time) { DataClassification = ToBeClassified; }
        field(99954; "Confirmed Pallets"; Decimal)
        {
            DataClassification = ToBeClassified;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99955; "Confirmed Lifts"; Decimal)
        {
            DataClassification = ToBeClassified;
            Caption = 'Confirmed Lifts';
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99956; "Confirmed Loose Boxes"; Decimal)
        {
            DataClassification = ToBeClassified;
            Caption = 'Confirmed Loose Boxes';
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99957; "Received Lifts"; Decimal)
        {
            DataClassification = ToBeClassified;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99958; "Received Loose Boxes"; Decimal)
        {
            DataClassification = ToBeClassified;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99959; "Received Pallets"; Decimal)
        {
            DataClassification = ToBeClassified;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99960; "No. of Items"; Integer) { }
        field(99961; Comments; Text[100]) { }
        field(99962; "Receiving Status"; Option)
        {
            Caption = 'Transportation Receiving Status';
            OptionMembers = "Provisional","Transportation Booked","Goods Arrived","No Show","Fixed slot","Surprise PO","Suspend";
            OptionCaption = 'Provisional,Transportation Booked,Goods Arrived,No Show,Fixed slot,Surprise PO,Suspend';
        }
        field(99963; "Received Date"; Date) { DataClassification = ToBeClassified; }
        field(99964; "Received Time"; Time) { DataClassification = ToBeClassified; }
        field(99965; "Shipping Carrier"; Text[50]) { DataClassification = ToBeClassified; }
        field(99966; "Delivery Term"; Text[50]) { DataClassification = ToBeClassified; }
        field(99967; "Vehicle Registration No"; Text[50]) { DataClassification = ToBeClassified; }
    }
}
