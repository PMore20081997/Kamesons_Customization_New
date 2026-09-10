namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;
using Microsoft.Warehouse.Request;

pageextension 99957 Sales_Order_Ext extends "Sales Order"
{
    layout
    {
        addlast(General)
        {
            field("Special Order"; Rec."Special Order")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Special Order field.', Comment = '%';
            }
            field("Group Branches"; Rec."Group Branches")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies that the customer is flagged as Group Branches: at a non-Hub location, item lines price at cost, with no markup. Set on the customer card.';
            }
        }
        addlast("Shipping and Billing")
        {

            field(Dispensary; Rec.Dispensary)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Dispensary field.', Comment = '%';
            }
            field("Retail "; Rec."Retail ")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Retail field.', Comment = '%';
            }
        }
        addlast(factboxes)
        {
            part(ReceiveBinContentDetails; "Bin Content Details")
            {
                SubPageLink = "Item No." = field("No.");
                ApplicationArea = all;
                Caption = 'Bin Content Details';
                Provider = SalesLines;
            }
            part(ItemManufacturerFactbox; "Item Manufacturer Factbox")
            {
                SubPageLink = "Item No" = field("No.");
                ApplicationArea = all;
                Caption = 'Item Manufacturer Factbox';
                Provider = SalesLines;
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(CreateInvtPickKnapp)
            {
                Caption = 'Create Inventory Pick';
                ApplicationArea = All;
                Image = CreateInventoryPickup;
                ToolTip = 'Create Inventory Pick(s) for this Sales Order, split by Knapp Tote if tote information exists.';

                trigger OnAction()
                var
                    L_WhseRequest: Record "Warehouse Request";
                    L_CreateInvtPick: Report "Create Invt. Pick";
                begin
                    L_WhseRequest.SetCurrentKey("Source Document", "Source No.");
                    L_WhseRequest.SetRange("Source Document", L_WhseRequest."Source Document"::"Sales Order");
                    L_WhseRequest.SetRange("Source No.", Rec."No.");
                    L_WhseRequest.SetRange("Document Status", L_WhseRequest."Document Status"::Released);

                    L_CreateInvtPick.SetTableView(L_WhseRequest);
                    // ShowError = TRUE: when run interactively for a single
                    // order, surface the reason nothing is created (order not
                    // released / shipping advice Complete not available / no
                    // stock) instead of skipping silently.
                    L_CreateInvtPick.InitializeRequest(false, true, false, false, true);
                    L_CreateInvtPick.UseRequestPage(false);
                    L_CreateInvtPick.RunModal();
                end;
            }
        }
        addlast(Promoted)
        {
            actionref(CreateInvtPickKnapp_Promoted; CreateInvtPickKnapp) { }
        }
    }
}
