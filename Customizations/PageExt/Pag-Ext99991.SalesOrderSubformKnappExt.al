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
            action(BulkLoadUnitDetailsLine)
            {
                Caption = 'BULK Load Unit Details';
                ApplicationArea = All;
                Image = ItemTrackingLines;
                ToolTip = 'View the BULK load units of this sales line: quantity handled and outstanding per inventory pick posting, and whether each load unit was sent to Knapp.';

                trigger OnAction()
                var
                    BulkLoadUnit: Record "BULK Load Unit Details";
                begin
                    BulkLoadUnit.SetRange("Sales Order No.", Rec."Document No.");
                    BulkLoadUnit.SetRange("Sales Order Line No.", Rec."Line No.");
                    Page.Run(Page::"BULK Load Unit Details List", BulkLoadUnit);
                end;
            }
        }


    }
}
