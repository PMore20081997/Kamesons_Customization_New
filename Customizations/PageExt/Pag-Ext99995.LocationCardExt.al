namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Location;

pageextension 99995 LocationCardExt extends "Location Card"
{
    layout
    {
        addlast(General)
        {
            field(Hub; Rec.Hub)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies that this is a Hub location. Sales order/quote lines from a Hub location with a value on the Branches dimension are priced at cost plus the margin configured on Sales & Receivables Setup; at a non-Hub location they are priced at 0.';
            }
        }
    }
}
