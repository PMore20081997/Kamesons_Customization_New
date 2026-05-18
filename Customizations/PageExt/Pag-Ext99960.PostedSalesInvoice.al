namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.History;

pageextension 99960 PostedSalesInvoice extends "Posted Sales Invoice"
{
    layout
    {
        addlast("Shipping Details")
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
    }
}
