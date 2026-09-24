namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// Which warehouse process the user is asking about on the
/// "Why This Happened?" screen (page 99941).
///
/// Each value maps to one explainer codeunit behind the dispatcher
/// (codeunit 99942 "Routing Explain Dispatch NDPP"):
///   Put-Away      -> codeunit 99944, mirrors codeunit 99983 "Put-Away Mgt. NDPP"
///   Bulk Replen   -> codeunit 99945, mirrors report 99971 "Cal _Bin Replenishment New"
///   Decant        -> codeunit 99946, mirrors codeunit 99991 "Create Decant Whse Reclass And Post"
/// </summary>
enum 99947 "Explained Process NDPP"
{
    Extensible = true;
    Caption = 'Process';

    value(0; "PutAway")
    {
        Caption = 'Put-Away';
    }
    value(1; "BulkReplen")
    {
        Caption = 'Bulk Replenishment';
    }
    value(2; "Decant")
    {
        Caption = 'Decant';
    }
}
