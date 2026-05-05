namespace Kamesons_Customization.Kamesons_Customization;
using System.Utilities;

page 99954 "Barcode Generator"
{
    ApplicationArea = All;
    Caption = '1D Barcode Generator';
    PageType = Card;
    UsageCategory = Tasks;
    SourceTable = Integer;
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(General)
            {
                ShowCaption = false;

                field(InputNumber; InputNumber)
                {
                    ApplicationArea = All;
                    Caption = 'Number';
                    ToolTip = 'Specifies the number or text to print as a 1D Code39 barcode.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(PrintBarcode)
            {
                ApplicationArea = All;
                Caption = 'Print';
                Image = Print;
                ToolTip = 'Print the report with the entered number and its 1D barcode.';

                trigger OnAction()
                var
                    BarcodeReport: Report "Barcode Print";
                begin
                    if InputNumber = '' then
                        Error(EmptyInputErr);
                    BarcodeReport.SetNumber(InputNumber);
                    BarcodeReport.RunModal();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(PrintBarcode_Promoted; PrintBarcode) { }
            }
        }
    }

    var
        InputNumber: Text[100];
        EmptyInputErr: Label 'Please enter a number before printing.';
}
