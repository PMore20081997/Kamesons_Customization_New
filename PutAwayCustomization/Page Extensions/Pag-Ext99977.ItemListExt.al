namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;

pageextension 99977 Item_ListExt extends "Item List"
{
    actions
    {
        addlast(Inventory)
        {
            action("Execute Test")
            {
                ApplicationArea = All;
                trigger OnAction()
                begin
                    Codeunit.Run(99973);
                end;
            }
        }
    }
}
