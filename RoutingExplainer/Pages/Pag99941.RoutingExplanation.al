namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;

/// <summary>
/// "Why This Happened?" - the self-service screen for warehouse users.
///
/// The user picks a process, enters or scans an item, optionally names a bin,
/// and presses Explain. The screen answers in plain English, backed by the
/// figures it used, so a warehouse operative can settle a question without
/// calling support.
///
/// Read-only and side-effect free: the source table is TEMPORARY, so nothing
/// is written anywhere. Safe to hand to any user with warehouse read rights.
/// </summary>
page 99941 "Routing Explanation NDPP"
{
    Caption = 'Why This Happened?';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    SourceTable = "Routing Explanation NDPP";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            group(EnterDetails)
            {
                Caption = 'Enter Details';
                InstructionalText = 'Choose the process you have a question about, then enter or scan the item.';

                field(ProcessCtrl; G_Process)
                {
                    ApplicationArea = All;
                    Caption = 'Process';
                    ToolTip = 'Specifies which warehouse process you want explained.';

                    trigger OnValidate()
                    begin
                        ClearResult();
                    end;
                }
                field(ItemNoCtrl; G_ItemNo)
                {
                    ApplicationArea = All;
                    Caption = 'Item No.';
                    TableRelation = Item."No.";
                    ToolTip = 'Specifies the item you have a question about.';

                    trigger OnValidate()
                    begin
                        G_ItemBarcode := '';
                        LoadItemDetails();
                    end;
                }
                field(ItemBarcodeCtrl; G_ItemBarcode)
                {
                    ApplicationArea = All;
                    Caption = 'Item Barcode';
                    ToolTip = 'Scan the item barcode instead of typing the item number.';

                    trigger OnValidate()
                    begin
                        ResolveBarcode();
                    end;
                }
                field(DescriptionCtrl; G_Description)
                {
                    ApplicationArea = All;
                    Caption = 'Description';
                    Editable = false;
                    ToolTip = 'Specifies the item description.';
                }
                field(RoutingTypeCtrl; G_RoutingType)
                {
                    ApplicationArea = All;
                    Caption = 'Routing Type';
                    Editable = false;
                    ToolTip = 'Specifies how this item is routed. BULK items are replenished through Bulk Replenishment; Flowrack and Static items go through Decant.';
                }
                field(BinCodeCtrl; G_BinCode)
                {
                    ApplicationArea = All;
                    Caption = 'Bin Code (optional)';
                    TableRelation = Bin.Code where("Location Code" = field("Location Code"));
                    ToolTip = 'Leave blank to check every bin set up for this item, or name one bin to narrow the answer to it.';

                    trigger OnValidate()
                    begin
                        ClearResult();
                    end;
                }
                field(LocationCodeCtrl; G_LocationCode)
                {
                    ApplicationArea = All;
                    Caption = 'Location Code';
                    TableRelation = Location.Code;
                    ToolTip = 'Specifies the Main Warehouse location. Defaults from Warehouse Setup.';

                    trigger OnValidate()
                    begin
                        ClearResult();
                    end;
                }
            }

            group(ResultGroup)
            {
                Caption = 'Answer';
                Visible = G_HasResult;

                field(OutcomeCtrl; Rec.Outcome)
                {
                    ApplicationArea = All;
                    Caption = 'Outcome';
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'Specifies what the system would do for this item right now.';
                }
                field(ExplanationCtrl; Rec.Explanation)
                {
                    ApplicationArea = All;
                    Caption = 'Why';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Specifies the reason, in plain English.';
                }
            }

            group(BinFactsGroup)
            {
                Caption = 'The Numbers Behind It';
                Visible = G_HasResult;

                part(BinFacts; "Routing Explanation Bins NDPP")
                {
                    ApplicationArea = All;
                    Caption = 'Bins';
                }
                field(RuleAppliedCtrl; Rec."Rule Applied")
                {
                    ApplicationArea = All;
                    Caption = 'Rule Applied';
                    Editable = false;
                    ToolTip = 'Specifies which rule decided the outcome.';
                }
                field(EvaluatedAtCtrl; Rec."Evaluated At")
                {
                    ApplicationArea = All;
                    Caption = 'Evaluated At';
                    Editable = false;
                    ToolTip = 'Specifies when this explanation was worked out. It is based on data as it stands now - if stock has moved since a document was created, the reason may differ.';
                }
            }

            group(ActivityGroup)
            {
                Caption = 'Recent Activity For This Item';
                Visible = G_HasActivity;

                part(Activity; "Routing Explanation Act. NDPP")
                {
                    ApplicationArea = All;
                    Caption = 'Recent Lines';
                }
            }

            group(DetailsTextGroup)
            {
                Caption = 'Details To Copy';
                Visible = G_ShowDetailsText;
                InstructionalText = 'Select the text below and copy it, then paste it into your email or support ticket.';

                field(DetailsTextCtrl; G_DetailsText)
                {
                    ApplicationArea = All;
                    Caption = 'Full Explanation';
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                    ToolTip = 'Specifies the full explanation as plain text, ready to select and copy.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExplainAction)
            {
                ApplicationArea = All;
                Caption = 'Explain';
                Image = Find;
                ToolTip = 'Work out why the system behaved the way it did for this item.';

                trigger OnAction()
                begin
                    RunExplain();
                end;
            }
            action(CopyDetailsAction)
            {
                ApplicationArea = All;
                Caption = 'Show Details To Copy';
                Image = Copy;
                Enabled = G_HasResult;
                ToolTip = 'Show the full explanation as plain text, ready to select and copy into an email or support ticket.';

                trigger OnAction()
                begin
                    CopyDetails();
                end;
            }
            action(OpenItemAction)
            {
                ApplicationArea = All;
                Caption = 'Open Item';
                Image = Item;
                Enabled = G_HasResult;
                ToolTip = 'Open the item card, to check or correct its setup.';

                trigger OnAction()
                var
                    Item: Record Item;
                begin
                    if Item.Get(G_ItemNo) then
                        Page.Run(Page::"Item Card", Item);
                end;
            }
        }

        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ExplainRef; ExplainAction) { }
                actionref(CopyDetailsRef; CopyDetailsAction) { }
                actionref(OpenItemRef; OpenItemAction) { }
            }
        }
    }

    var
        G_Dispatch: Codeunit "Routing Explain Dispatch NDPP";
        G_Facts: Codeunit "Routing Explainer Facts NDPP";
        G_Process: Enum "Explained Process NDPP";
        G_ItemNo: Code[20];
        G_ItemBarcode: Code[50];
        G_Description: Text[100];
        G_RoutingType: Enum "Item Routing Type NDPP";
        G_BinCode: Code[20];
        G_LocationCode: Code[10];
        G_HasResult: Boolean;
        G_HasActivity: Boolean;
        G_DetailsText: Text;
        G_ShowDetailsText: Boolean;
        BarcodeNotFoundErr: Label 'No item was found with barcode %1.', Comment = '%1 = barcode';

    trigger OnOpenPage()
    begin
        G_LocationCode := CopyStr(G_Facts.GetMainLocation(), 1, MaxStrLen(G_LocationCode));
    end;

    local procedure RunExplain()
    begin
        G_Dispatch.Explain(Rec, G_Process, G_ItemNo, G_ItemBarcode, G_BinCode, G_LocationCode);

        // The dispatcher resolves the item, so reflect what it settled on.
        Rec.Reset();
        Rec.SetRange("Row Type", Rec."Row Type"::Header);
        if Rec.FindFirst() then begin
            G_ItemNo := Rec."Item No.";
            G_Description := Rec.Description;
            G_RoutingType := Rec."Routing Type";
        end;
        Rec.Reset();

        G_HasResult := true;
        LoadSubParts();
        CurrPage.Update(false);
    end;

    local procedure LoadSubParts()
    var
        BinBuffer: Record "Routing Explanation NDPP" temporary;
        ActivityBuffer: Record "Routing Explanation NDPP" temporary;
    begin
        CopyRows(Rec."Row Type"::BinFact, BinBuffer);
        CurrPage.BinFacts.Page.SetRows(BinBuffer);

        CopyRows(Rec."Row Type"::Activity, ActivityBuffer);
        G_HasActivity := not ActivityBuffer.IsEmpty();
        CurrPage.Activity.Page.SetRows(ActivityBuffer);
    end;

    local procedure CopyRows(RowType: Option Header,BinFact,Activity; var Target: Record "Routing Explanation NDPP" temporary)
    var
        Source: Record "Routing Explanation NDPP" temporary;
    begin
        Target.Reset();
        Target.DeleteAll();

        Source.Copy(Rec, true);
        Source.Reset();
        Source.SetRange("Row Type", RowType);
        if not Source.FindSet() then
            exit;

        repeat
            Target := Source;
            Target.Insert();
        until Source.Next() = 0;
    end;

    local procedure LoadItemDetails()
    var
        Item: Record Item;
    begin
        ClearResult();
        Clear(G_Description);
        Clear(G_RoutingType);

        if G_ItemNo = '' then
            exit;
        if not Item.Get(G_ItemNo) then
            exit;

        G_Description := Item.Description;
        G_RoutingType := Item."Routing Type";
    end;

    local procedure ResolveBarcode()
    var
        Item: Record Item;
    begin
        ClearResult();
        if G_ItemBarcode = '' then
            exit;

        if not G_Facts.ResolveItem('', G_ItemBarcode, Item) then begin
            Clear(G_Description);
            Clear(G_RoutingType);
            Error(BarcodeNotFoundErr, G_ItemBarcode);
        end;

        G_ItemNo := Item."No.";
        G_Description := Item.Description;
        G_RoutingType := Item."Routing Type";
    end;

    /// <summary>
    /// Reveals the whole explanation as one block of selectable text, so the
    /// user can highlight it and copy it into an email or a support ticket.
    ///
    /// A direct clipboard write would need the System Application's
    /// "Clipboard Management" codeunit, which this app does not depend on.
    /// Rather than add a dependency for one button, the text is shown in a
    /// multi-line field the user can select - same end result, no new
    /// dependency.
    /// </summary>
    local procedure CopyDetails()
    begin
        G_DetailsText := G_Dispatch.BuildClipboardText(Rec);
        G_ShowDetailsText := G_DetailsText <> '';
        CurrPage.Update(false);
    end;

    local procedure ClearResult()
    begin
        G_HasResult := false;
        G_HasActivity := false;
        G_ShowDetailsText := false;
        Clear(G_DetailsText);
    end;
}
