namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Customer;

pageextension 99989 CustomerCardExt extends "Customer Card"
{
    layout
    {
        addlast(General)
        {
            field("Group Branches"; Rec."Group Branches")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies that at a non-Hub location (see the Hub field on the Location card), sales orders and quotes for this customer are priced at cost, with no markup.';
            }
        }
    }
}
