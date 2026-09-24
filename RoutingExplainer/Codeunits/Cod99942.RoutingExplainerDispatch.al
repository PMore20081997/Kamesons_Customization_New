namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using System.Utilities;

/// <summary>
/// Entry point behind page 99941 "Why This Happened?". Resolves the item,
/// writes the Header row, then hands off to the explainer for the chosen
/// process.
///
/// WHY THE ENGINES ARE MIRRORED RATHER THAN CALLED
///   The three engines all MUTATE as they decide: codeunit 99983 rewrites and
///   splits Warehouse Activity Lines, report 99971 inserts worksheet rows, and
///   codeunit 99991 writes journal lines. None can be run for a diagnostic
///   without side effects, and refactoring them to report their reasons would
///   mean editing live routing, replenishment and posting code for the sake of
///   a read-only screen. So each explainer re-walks the same rules read-only.
///
///   The cost is that a rule change must be made in two places. Each explainer
///   names the engine and rule order it mirrors in its header, and
///   enum 99943 groups its values by engine, so the pairing stays visible.
///
/// LIMITATION worth repeating to users: explanations are derived from data as
/// it stands NOW. For a document raised weeks ago, stock may since have moved
/// and the explanation may differ from the original decision. The screen shows
/// the evaluation timestamp for exactly this reason.
/// </summary>
codeunit 99942 "Routing Explain Dispatch NDPP"
{
    Access = Public;
    Permissions = tabledata Item = r;

    var
        G_Facts: Codeunit "Routing Explainer Facts NDPP";
        ItemNotFoundErr: Label 'No item was found for the details entered. Check the item number, or scan the barcode again.';
        NoInputErr: Label 'Enter an item number or scan a barcode before choosing Explain.';

    /// <summary>
    /// Runs the explanation. Clears the buffer, so it is safe to call
    /// repeatedly as the user changes the inputs.
    /// </summary>
    procedure Explain(var Buffer: Record "Routing Explanation NDPP" temporary; Process: Enum "Explained Process NDPP"; ItemNo: Code[20]; Barcode: Code[50]; BinCode: Code[20]; LocationCode: Code[10])
    var
        Item: Record Item;
        PutAwayExplainer: Codeunit "Put-Away Explainer NDPP";
        BulkReplenExplainer: Codeunit "Bulk Replen Explainer NDPP";
        DecantExplainer: Codeunit "Decant Explainer NDPP";
    begin
        if (ItemNo = '') and (Barcode = '') then
            Error(NoInputErr);

        if not G_Facts.ResolveItem(ItemNo, Barcode, Item) then
            Error(ItemNotFoundErr);

        Buffer.Reset();
        Buffer.DeleteAll();

        WriteHeader(Buffer, Process, Item, Barcode, BinCode, LocationCode);

        case Process of
            Process::PutAway:
                PutAwayExplainer.Explain(Buffer, Item, BinCode);
            Process::BulkReplen:
                BulkReplenExplainer.Explain(Buffer, Item, BinCode);
            Process::Decant:
                DecantExplainer.Explain(Buffer, Item, BinCode);
        end;

        // Land the user on the Header row so the verdict is what they see.
        Buffer.Reset();
        Buffer.SetRange("Row Type", Buffer."Row Type"::Header);
        if Buffer.FindFirst() then;
        Buffer.Reset();
    end;

    local procedure WriteHeader(var Buffer: Record "Routing Explanation NDPP" temporary; Process: Enum "Explained Process NDPP"; Item: Record Item; Barcode: Code[50]; BinCode: Code[20]; LocationCode: Code[10])
    begin
        Buffer.InitRow(Buffer, Buffer."Row Type"::Header);
        Buffer.Process := Process;
        Buffer."Item No." := Item."No.";
        Buffer."Item Barcode" := Barcode;
        Buffer.Description := Item.Description;
        Buffer."Routing Type" := Item."Routing Type";
        Buffer."Bin Code" := BinCode;
        Buffer."Location Code" := LocationCode;
        Buffer."Evaluated At" := CurrentDateTime();
        Buffer.Insert();
    end;

    /// <summary>
    /// The whole explanation as plain text, for the Copy Details action.
    /// Support tickets then arrive with the full diagnostic already in them.
    /// </summary>
    procedure BuildClipboardText(var Buffer: Record "Routing Explanation NDPP" temporary): Text
    var
        Builder: TextBuilder;
        HeaderTxt: Label 'WHY THIS HAPPENED - %1', Comment = '%1 = process';
        ItemLineTxt: Label 'Item %1  %2', Comment = '%1 = item no.; %2 = description';
        RoutingLineTxt: Label 'Routing Type: %1', Comment = '%1 = routing type';
        OutcomeLineTxt: Label 'OUTCOME: %1', Comment = '%1 = outcome';
        WhyLineTxt: Label 'WHY: %1', Comment = '%1 = explanation';
        RuleLineTxt: Label 'Rule applied: %1', Comment = '%1 = rule';
        BinsHeaderTxt: Label 'BINS';
        BinLineTxt: Label '  %1 / %2 (%3): on hand %4, min %5, max %6, expiry %7 to %8', Comment = '%1 = location; %2 = bin; %3 = role; %4 = on hand; %5 = min; %6 = max; %7 = earliest; %8 = latest';
        ActivityHeaderTxt: Label 'RECENT ACTIVITY';
        ActivityLineTxt: Label '  %1  %2  %3 to %4', Comment = '%1 = date; %2 = doc no.; %3 = qty; %4 = bin';
        EvaluatedTxt: Label 'Evaluated at %1. Based on data as it stands now.', Comment = '%1 = timestamp';
    begin
        Buffer.Reset();
        Buffer.SetRange("Row Type", Buffer."Row Type"::Header);
        if Buffer.FindFirst() then begin
            Builder.AppendLine(StrSubstNo(HeaderTxt, Format(Buffer.Process)));
            Builder.AppendLine(StrSubstNo(ItemLineTxt, Buffer."Item No.", Buffer.Description));
            Builder.AppendLine(StrSubstNo(RoutingLineTxt, Format(Buffer."Routing Type")));
            Builder.AppendLine('');
            Builder.AppendLine(StrSubstNo(OutcomeLineTxt, Buffer.Outcome));
            Builder.AppendLine('');
            Builder.AppendLine(StrSubstNo(WhyLineTxt, Buffer.Explanation));
            Builder.AppendLine('');
            Builder.AppendLine(StrSubstNo(RuleLineTxt, Format(Buffer."Rule Applied")));
            Builder.AppendLine(StrSubstNo(EvaluatedTxt, Format(Buffer."Evaluated At")));
        end;

        Buffer.Reset();
        Buffer.SetRange("Row Type", Buffer."Row Type"::BinFact);
        if Buffer.FindSet() then begin
            Builder.AppendLine('');
            Builder.AppendLine(BinsHeaderTxt);
            repeat
                Builder.AppendLine(StrSubstNo(BinLineTxt, Buffer."Fact Location Code", Buffer."Fact Bin Code", Buffer."Bin Role",
                                              G_Facts.FormatQty(Buffer."Qty On Hand"), G_Facts.FormatQty(Buffer."Min Qty"),
                                              G_Facts.FormatQty(Buffer."Max Qty"), G_Facts.FormatDate(Buffer."Earliest Expiry"),
                                              G_Facts.FormatDate(Buffer."Latest Expiry")));
            until Buffer.Next() = 0;
        end;

        Buffer.Reset();
        Buffer.SetRange("Row Type", Buffer."Row Type"::Activity);
        if Buffer.FindSet() then begin
            Builder.AppendLine('');
            Builder.AppendLine(ActivityHeaderTxt);
            repeat
                Builder.AppendLine(StrSubstNo(ActivityLineTxt, G_Facts.FormatDate(Buffer."Activity Date"), Buffer."Document No.",
                                              G_Facts.FormatQty(Buffer."Activity Qty"), Buffer."Activity Bin Code"));
            until Buffer.Next() = 0;
        end;

        Buffer.Reset();
        exit(Builder.ToText());
    end;
}
