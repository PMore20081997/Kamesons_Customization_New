tableextension 99950 "Warehousereceiptheaderext" extends "Warehouse Receipt Header"
{
    fields
    {
        field(60150; "Transportation Arranged By"; Code[20])
        {
            Editable = true;
        }
        field(60151; "Preferred Delivery Date"; Date)
        {
            DataClassification = ToBeClassified;
            NotBlank = true;
        }
        field(60152; "Confirmed Delivery Date"; Date)
        {
            DataClassification = ToBeClassified;
            NotBlank = true;
        }
        field(60153; "Confirmed Delivery Time"; Time)
        {
            DataClassification = ToBeClassified;
            NotBlank = true;
        }
        field(60154; "Confirmed Pallets"; Decimal)
        {
            DataClassification = ToBeClassified;
            //FieldClass = FlowField;
            Editable = true;
            //CalcFormula = sum("Gate Entry Line"."Total Pallet" where("No." = field("No.")));
        }
        field(60155; "Confirmed Lifts"; Decimal)
        {
            DataClassification = ToBeClassified;
            //FieldClass = FlowField;
            Editable = true;
            Caption = 'Confirmed Lifts';
            //CalcFormula = sum("Gate Entry Line".Lifts where("No." = field("No.")));
        }
        field(60156; "Confirmed Loose Boxes"; Decimal)
        {
            DataClassification = ToBeClassified;
            //FieldClass = FlowField;
            Editable = true;
            Caption = 'Confirmed Loose Boxes';
            //CalcFormula = sum("Gate Entry Line"."Loose Boxes" where("No." = field("No.")));
        }
        field(60157; "Received Lifts"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(60158; "Received Loose Boxes"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(60159; "Received Pallets"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(60160; "No. of Items"; Integer) //need to ask team for calcformula
        {
            //FieldClass = FlowField;
            //CalcFormula = count("Gate Entry Line" where("No." = field("No.")));
        }
        field(60161; Comments; Text[100])
        {
        }
        field(60162; "Receiving Status"; Option)
        {
            Caption = 'Transportation Receiving Status';
            OptionMembers = "Provisional","Transportation Booked","Goods Arrived","No Show","Fixed slot","Surprise PO","Suspend";
            OptionCaption = 'Provisional,Transportation Booked,Goods Arrived,No Show,Fixed slot,Surprise PO,Suspend';
            // trigger OnValidate()
            // var
            //     gateEntryLine: Record "Gate Entry Line";
            //     warehouseReceiptHeader: Record "Warehouse Receipt Header";
            //     purcHeader: Record "Purchase Header";
            // begin
            //     gateEntryLine.Reset();
            //     gateEntryLine.setrange("No.", Rec."No.");
            //     if gateEntryLine.FindSet() then begin
            //         repeat
            //             gateEntryLine.Validate("Transportation Receipt Status", Rec."Receipt Status");
            //             gateEntryLine.Modify(true);
            //         until gateEntryLine.Next() = 0;

            //     end;
            //     gateEntryLine.Reset();
            //     gateEntryLine.setrange("No.", Rec."No.");
            //     if gateEntryLine.FindSet() then begin
            //         repeat
            //             warehouseReceiptHeader.Reset();
            //             warehouseReceiptHeader.SetRange("No.", gateEntryLine."Warehouse Receipt No.");
            //             if warehouseReceiptHeader.FindFirst() then begin
            //                 warehouseReceiptHeader."Receipt Status" := format(Rec."Receipt Status");
            //                 warehouseReceiptHeader.Modify();
            //             end;
            //         until gateEntryLine.Next() = 0;
            //     end;
            //     gateEntryLine.Reset();
            //     gateEntryLine.setrange("No.", Rec."No.");
            //     if gateEntryLine.FindSet() then begin
            //         repeat
            //             purcHeader.Reset();
            //             purcHeader.SetRange("No.", gateEntryLine."Document no");
            //             if purcHeader.FindFirst() then begin
            //                 purcHeader."Receipt Status" := format(Rec."Receipt Status");
            //                 purcHeader.Modify();
            //             end;
            //         until gateEntryLine.Next() = 0;
            //     end;

            // end;
        }
        field(60163; "Received Date"; Date)
        {
            DataClassification = ToBeClassified;
        }
        field(60164; "Received Time"; Time)
        {
            DataClassification = ToBeClassified;
        }
        field(60165; "Shipping Carrier"; Text[50])
        {
            DataClassification = ToBeClassified;
        }
        field(60166; "Delivery Term"; Text[50])
        {
            DataClassification = ToBeClassified;
        }
        field(60167; "Vehicle Registration No"; Text[50])
        {
            DataClassification = ToBeClassified;
        }
    }

}