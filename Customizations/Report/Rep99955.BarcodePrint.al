namespace Kamesons_Customization.Kamesons_Customization;
using System.Utilities;

report 99955 "Barcode Print"
{
    Caption = 'Barcode Print';
    DefaultRenderingLayout = "Barcode Print Layout";
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;

    dataset
    {
        dataitem(DummyInt; Integer)
        {
            DataItemTableView = sorting(Number) where(Number = const(1));

            column(NumberValue; NumberValueGlobal) { }
            column(BarcodeText; BarcodeTextGlobal) { }
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(NumberToPrint; NumberValueGlobal)
                    {
                        ApplicationArea = All;
                        Caption = 'Number';
                        ToolTip = 'Specifies the number or text to encode as a Code39 barcode.';
                    }
                }
            }
        }
    }

    rendering
    {
        layout("Barcode Print Layout")
        {
            Type = RDLC;
            LayoutFile = './Customizations/Report/BarcodePrint.rdl';
            Caption = 'Barcode Print Layout';
        }
    }

    trigger OnPreReport()
    begin
        if NumberValueGlobal = '' then
            Error(MissingNumberErr);
        BarcodeTextGlobal := '*' + UpperCase(NumberValueGlobal) + '*';
    end;

    var
        NumberValueGlobal: Text[100];
        BarcodeTextGlobal: Text[250];
        MissingNumberErr: Label 'A number must be provided to print the barcode.';

    procedure SetNumber(NewValue: Text[100])
    begin
        NumberValueGlobal := NewValue;
    end;
}
