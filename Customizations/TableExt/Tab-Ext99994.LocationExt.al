namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Location;

/// <summary>
/// "Hub" flag. Drives sales-line pricing for Order/Quote lines that carry a
/// value on the "BRANCHES" dimension: a Hub location prices at cost plus the
/// margin configured on Sales & Receivables Setup; a non-Hub location prices
/// at 0. See Cod99976 SalesLine_OnAfterValidateNo_ApplyHubPricing.
/// </summary>
tableextension 99994 LocationExt extends Location
{
    fields
    {
        field(99971; Hub; Boolean)
        {
            Caption = 'Hub';
            DataClassification = CustomerContent;
        }
    }
}
