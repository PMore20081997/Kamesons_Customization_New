namespace Kamesons_Customization.Kamesons_Customization;

using System.Security.User;

pageextension 99954 UserSetupExt extends "User Setup"
{
    layout
    {
        addlast(Control1)
        {

            field("Allow Second Check"; Rec."Allow Second Check")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Allow Second Check field.', Comment = '%';
            }
        }
    }
}
