namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Customer;

/// <summary>
/// "Group Branches" flag. Combines with Location."Hub" to price sales lines:
/// at a non-Hub location, a Group Branches customer is priced at cost
/// (no markup) regardless of the order's dimensions. See the Sales Line "No."
/// validate subscriber in codeunit Customize_Events (Cod99976). Flows onto the
/// Sales Header when the customer is selected on a sales order (see
/// SalesHeader_OnAfterValidateSellToCustomerNo_FlowGroupBranches in Cod99976).
/// </summary>
tableextension 99969 CustomerExt extends Customer
{
    fields
    {
        field(99972; "Group Branches"; Boolean)
        {
            Caption = 'Group Branches';
            DataClassification = CustomerContent;
        }
    }
}
