namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Sales.History;

pageextension 99959 PostedSalesShptExt extends "Posted Sales Shipment"
{
    layout
    {
        addlast(Shipping)
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
