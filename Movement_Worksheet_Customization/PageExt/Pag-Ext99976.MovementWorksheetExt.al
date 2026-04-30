namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Worksheet;
using Microsoft.Inventory.Location;
using Microsoft.Warehouse.Structure;

pageextension 99976 MovementWorksheetExt extends "Movement Worksheet"
{
    layout
    {

    }
    actions
    {
        modify("Calculate Bin &Replenishment")
        {
            Visible = false;
        }
        addlast("F&unctions")
        {
            action("Calculate Movement Worksheet")
            {
                ApplicationArea = All;
                Caption = 'Calculate Movement Worksheet';
                Ellipsis = true;
                Image = CalculateBinReplenishment;
                ToolTip = 'Calculate the movement of items from bulk storage bins with lower bin rankings to bins with a high bin ranking in the picking areas.';

                trigger OnAction()
                var
                    Location: Record Location;
                    BinContent: Record "Bin Content";
                    ReplenishBinContent: Report "Calculate Bin Rep And Movement";
                    L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
                begin
                    Location.Get(Rec."Location Code");
                    ReplenishBinContent.InitializeRequest(
                      Rec."Worksheet Template Name", Rec.Name, L_KamWhseSetupLookup.GetMainLocation(),
                      Location."Allow Breakbulk", false, false);

                    ReplenishBinContent.SetTableView(BinContent);
                    //OnCalculateBinAndReplenishmentActionOnBeforeReplenishBinContentRun(ReplenishBinContent, Rec, Location);
                    ReplenishBinContent.Run();
                    Clear(ReplenishBinContent);
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(Calculate_Movement_Worksheet; "Calculate Movement Worksheet")
            {

            }
        }
    }

}
