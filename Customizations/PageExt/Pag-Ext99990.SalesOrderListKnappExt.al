namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.Document;

pageextension 99985 SalesOrderListKnappExt extends "Sales Order List"
{
    actions
    {
        addlast(processing)
        {
            action(KnappToteInfoList)
            {
                Caption = 'Knapp Tote Information';
                ApplicationArea = All;
                Image = ItemTrackingLines;
                ToolTip = 'View or edit Knapp tote information for the selected sales order.';

                trigger OnAction()
                var
                    KnappToteInfo: Record "Knapp Tote Information";
                    KnappToteInfoList: Page "Knapp Tote Info List";
                begin
                    KnappToteInfo.SetRange("Sales Order No.", Rec."No.");
                    KnappToteInfoList.SetTableView(KnappToteInfo);
                    KnappToteInfoList.Run();
                end;
            }
        }
        addlast(Promoted)
        {
            actionref(KnappToteInfoList_Promoted; KnappToteInfoList) { }
        }
    }
}
