namespace Kamesons_Customization.Kamesons_Customization;

using System.Security.User;

tableextension 99955 UserSetupExt extends "User Setup"
{
    fields
    {
        field(99950; "Allow Second Check"; Boolean)
        {
            Caption = 'Second Check Approver';
            DataClassification = ToBeClassified;
        }
    }
}
