tableextension 99950 "Warehousereceiptheaderext" extends "Warehouse Receipt Header"
{
    fields
    {
        field(99950; "Transportation Arranged By"; Code[20])
        {

        }
        field(99951; "Preferred Delivery Date"; Date)
        {
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(99952; "Expected Delivery Date"; Date)
        {
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(99953; "Expected Delivery Time"; Time)
        {
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(99954; "Expected Pallets"; Decimal)
        {
            DataClassification = CustomerContent;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99955; "Expected Lifts"; Decimal)
        {
            DataClassification = CustomerContent;
            Caption = 'Expected Lifts';
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99956; "Expected Loose Boxes"; Decimal)
        {
            DataClassification = CustomerContent;
            Caption = 'Expected Loose Boxes';
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99957; "Received Lifts"; Decimal)
        {
            DataClassification = CustomerContent;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99958; "Received Loose Boxes"; Decimal)
        {
            DataClassification = CustomerContent;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99959; "Received Pallets"; Decimal)
        {
            DataClassification = CustomerContent;
            BlankZero = true;
            DecimalPlaces = 0 : 5;
        }
        field(99960; "No. of Items"; Integer) //need to ask team for calcformula
        {
        }
        field(99961; Comments; Text[100])
        {
        }
        field(99962; "Receiving Status"; Enum "Receiving Status")
        {
            Caption = 'Transportation Receiving Status';
            DataClassification = CustomerContent;
        }
        field(99963; "Received Date"; Date)
        {
            DataClassification = CustomerContent;
        }
        field(99964; "Received Time"; Time)
        {
            DataClassification = CustomerContent;
        }
        field(99965; "Shipping Carrier"; Text[50])
        {
            DataClassification = CustomerContent;
        }
        field(99966; "Delivery Term"; Text[50])
        {
            DataClassification = CustomerContent;
        }
        field(99967; "Vehicle Registration No"; Text[50])
        {
            DataClassification = CustomerContent;
        }
    }

}