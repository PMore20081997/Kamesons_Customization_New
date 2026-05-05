namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;

pageextension 99956 Bins_Ext extends Bins
{
    layout
    {
        addlast(Control1)
        {
                
            field(Bulk; Rec.Bulk)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bulk field.', Comment = '%';
            }
            field(Static; Rec.Static)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Static field.', Comment = '%';
            }
            field(Flowrack; Rec.Flowrack)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Flowrack field.', Comment = '%';
            }
            field(HighBay; Rec.HighBay)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the High Bay field.', Comment = '%';
            }
        }
    }
}
