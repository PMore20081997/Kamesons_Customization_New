namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;

pageextension 99986 SalesOrderSubformKnappExt extends "Sales Order Subform"
{
    actions
    {
        addlast(processing)
        {
            action(KnappToteInfoLine)
            {
                Caption = 'Knapp Tote Information';
                ApplicationArea = All;
                Image = ItemTrackingLines;
                ToolTip = 'View or add Knapp tote assignments for this sales line. Enter the tote number and quantity for each tote.';

                trigger OnAction()
                var
                    KnappToteInfo: Record "Knapp Tote Information";
                    KnappToteInfoList: Page "Knapp Tote Info List";
                begin
                    KnappToteInfo.SetRange("Sales Order No.", Rec."Document No.");
                    KnappToteInfo.SetRange("Sales Order Line No.", Rec."Line No.");
                    KnappToteInfo.SetRange("Item No.", Rec."No.");
                    KnappToteInfoList.SetTableView(KnappToteInfo);
                    KnappToteInfoList.Run();
                end;
            }
        }


    }
}
