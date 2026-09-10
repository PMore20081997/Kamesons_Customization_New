tableextension 99979 SalesAndRecExt extends "Sales & Receivables Setup"
{
    fields
    {
        field(99971; "Replenishment Date Filter"; DateFormula)
        {
            Caption = 'Replenishment Date Filter';
            DataClassification = CustomerContent;
        }
        // Margin applied on top of Unit Cost (LCY) to derive the Unit Price for
        // sales lines posted from a Hub location (Location."Hub" = TRUE) that
        // carry a value on the "BRANCHES" dimension. Kept configurable here
        // rather than hard-coded — see Cod99976
        // SalesLine_OnAfterValidateNo_ApplyHubPricing. Set to 18 for the
        // current business rule.
        field(99972; "Hub Sales Margin %"; Decimal)
        {
            Caption = 'Hub Sales Margin %';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
    }
}
