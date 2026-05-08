// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Warehouse.Structure;

using Microsoft.Inventory.Location;
using Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Worksheet;

report 99973 "Calculate Bin Rep And Movement"
{
    Caption = 'Calculate Movement Replenishment';
    ProcessingOnly = true;

    dataset
    {
        dataitem("Bin Content"; "Bin Content")
        {
            DataItemTableView = sorting("Location Code", "Item No.", "Warehouse Class Code", Fixed, "Bin Ranking") order(descending) where("Min. Qty." = filter(> 0));
            RequestFilterFields = "Item No.", "Bin Code";

            trigger OnPreDataItem()
            begin
                ReplenishmentMgt.Initialize(WhseWkshTemplateName, WhseWkshName, LocationCode, DoNotFillQtytoHandle);
            end;

            trigger OnAfterGetRecord()
            begin
                ReplenishmentMgt.ProcessBinContent("Bin Content");
            end;

            trigger OnPostDataItem()
            begin
                if ReplenishmentMgt.GetLinesInserted() = 0 then
                    if not HideDialog then
                        Message(NothingToReplenishMsg);
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(WorksheetTemplateName; WhseWkshTemplateName)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Worksheet Template Name';
                        TableRelation = "Whse. Worksheet Template";
                        ToolTip = 'Specifies the name of the worksheet template that applies to the movement lines.';

                        trigger OnValidate()
                        begin
                            if WhseWkshTemplateName = '' then
                                WhseWkshName := '';
                        end;
                    }
                    field(WorksheetName; WhseWkshName)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Worksheet Name';
                        ToolTip = 'Specifies the name of the worksheet the movement lines will belong to.';
                        Visible = false;
                    }
                    field(LocCode; LocationCode)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Location Code';
                        TableRelation = Location;
                        ToolTip = 'Specifies the PICK BULK location whose fixed bins are checked for stock below Min. Qty.';
                        Visible = false;
                    }
                    field(DoNotFillQtytoHandle; DoNotFillQtytoHandle)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Do Not Fill Qty. to Handle';
                        ToolTip = 'Specifies that the Quantity to Handle field on each worksheet line must be filled manually.';
                    }
                }
            }
        }
    }

    var
        ReplenishmentMgt: Codeunit "Kam Replenishment Mgt.";
        NothingToReplenishMsg: Label 'There is nothing to replenish.';

    protected var
        WhseWkshTemplateName: Code[10];
        WhseWkshName: Code[10];
        DoNotFillQtytoHandle: Boolean;
        HideDialog: Boolean;
        LocationCode: Code[10];
        AllowBreakbulk: Boolean;

    procedure InitializeRequest(WhseWkshTemplateName2: Code[10]; WhseWkshName2: Code[10]; LocationCode2: Code[10]; AllowBreakbulk2: Boolean; HideDialog2: Boolean; DoNotFillQtytoHandle2: Boolean)
    begin
        WhseWkshTemplateName := WhseWkshTemplateName2;
        WhseWkshName := WhseWkshName2;
        LocationCode := LocationCode2;
        AllowBreakbulk := AllowBreakbulk2;
        HideDialog := HideDialog2;
        DoNotFillQtytoHandle := DoNotFillQtytoHandle2;
    end;
}
