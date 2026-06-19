// Global namespace (see note in Cod99966) so `extends "Registered Put-away"`
// resolves by name regardless of that page's namespace.

/// <summary>
/// Manual entry point for the Pallet-No. reclassification on a registered
/// Put-Away. Normally the reclassification posts automatically at registration
/// (see "Pallet Reclass Subscribers NDPP"); this action lets a user post it when
/// the automatic run failed. The engine only processes not-yet-reclassified
/// lines, so clicking it again on a fully-posted document errors out — the guard
/// against double reclassification.
/// </summary>
pageextension 99970 RegPutAwayExt extends "Registered Put-away"
{
    actions
    {
        addlast(processing)
        {
            action(PostPalletReclass)
            {
                ApplicationArea = All;
                Caption = 'Post Pallet Reclassification';
                Image = Post;
                ToolTip = 'Post the Package No. -> Pallet No. reclassification for this registered put-away. Use this only if the automatic reclassification at registration did not complete. Already-reclassified lines are skipped, and a fully-reclassified document cannot be reclassified again.';

                trigger OnAction()
                var
                    PalletReclassMgt: Codeunit "Pallet Reclass Mgt. NDPP";
                begin
                    PalletReclassMgt.ProcessRegisteredPutAway(Rec, true);
                end;
            }
        }
    }
}
