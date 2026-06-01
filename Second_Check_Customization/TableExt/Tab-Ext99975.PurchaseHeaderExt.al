namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Purchases.Document;
using System.Security.AccessControl;
using Microsoft.CRM.Team;
using System.Security.User;

tableextension 99975 Purchase_Header_Ext extends "Purchase Header"
{
    fields
    {
        field(99954; "Expected Pallets"; Decimal)
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
        field(99971; "Second Check"; Enum "Second Check Status")
        {
            trigger OnValidate()
            var
                L_SecondCheck_Events: Codeunit SecondCheck_Events;
            begin
                L_SecondCheck_Events.ValidateSecondCheck(Rec);
            end;
        }
        field(99972; "Second Check User"; Code[100])
        {
            TableRelation = User."User Name";
        }
        field(99973; "Second Check Date & Time"; DateTime)
        {

        }
        field(99974; "Whse. Receipt Error"; Text[1024])
        {
            DataClassification = CustomerContent;
        }
    }
}
