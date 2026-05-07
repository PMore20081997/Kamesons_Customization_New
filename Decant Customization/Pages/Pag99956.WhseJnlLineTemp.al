namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Journal;

page 99956 WhseJnlLineTemp
{
    ApplicationArea = All;
    Caption = 'WhseJnlLineTemp';
    PageType = List;
    SourceTable = "Warehouse Journal Line";
    UsageCategory = Lists;
    
    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Bin Code"; Rec."Bin Code")
                {
                    ToolTip = 'Specifies the bin where the items are picked or put away.';
                }
                field(Cubage; Rec.Cubage)
                {
                    ToolTip = 'Specifies the total cubage of the items on the warehouse journal line.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the item.';
                }
                field("Entry Type"; Rec."Entry Type")
                {
                    ToolTip = 'Specifies the type of transaction that will be registered from the line.';
                }
                field("Expiration Date"; Rec."Expiration Date")
                {
                    ToolTip = 'Specifies the last date that the item on the line can be used.';
                }
                field("From Bin Code"; Rec."From Bin Code")
                {
                    ToolTip = 'Specifies the code of the bin from which the item on the journal line is taken.';
                }
                field("From Bin Type Code"; Rec."From Bin Type Code")
                {
                    ToolTip = 'Specifies the value of the From Bin Type Code field.', Comment = '%';
                }
                field("From Zone Code"; Rec."From Zone Code")
                {
                    ToolTip = 'Specifies the code of the zone from which the item on the journal line is taken.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the number of the item on the journal line.';
                }
                field("Journal Batch Name"; Rec."Journal Batch Name")
                {
                    ToolTip = 'Specifies the name of the journal batch, a personalized journal layout, that the entries were posted from.';
                }
                field("Journal Template Name"; Rec."Journal Template Name")
                {
                    ToolTip = 'Specifies the name of the journal template, the basis of the journal batch, that the entries were posted from.';
                }
                field("Line No."; Rec."Line No.")
                {
                    ToolTip = 'Specifies the number of the warehouse journal line.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'Specifies the code of the location to which the journal line applies.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the same as for the field in the Item Journal window.';
                }
                field("Manufacturer Code"; Rec."Manufacturer Code")
                {
                    ToolTip = 'Specifies the value of the Manufacturer Code field.', Comment = '%';
                }
                field("New Expiration Date"; Rec."New Expiration Date")
                {
                    ToolTip = 'Specifies the value of the New Expiration Date field.', Comment = '%';
                }
                field("New Lot No."; Rec."New Lot No.")
                {
                    ToolTip = 'Specifies the value of the New Lot No. field.', Comment = '%';
                }
                field("New Package No."; Rec."New Package No.")
                {
                    ToolTip = 'Specifies the value of the New Package No. field.', Comment = '%';
                }
                field("New Serial No."; Rec."New Serial No.")
                {
                    ToolTip = 'Specifies the value of the New Serial No. field.', Comment = '%';
                }
                field("Package No."; Rec."Package No.")
                {
                    ToolTip = 'Specifies the same as for the field in the Item Journal window.';
                }
                field("Phys Invt Counting Period Code"; Rec."Phys Invt Counting Period Code")
                {
                    ToolTip = 'Specifies a code for the physical inventory counting period, if the counting period functionality was used when the line was created.';
                }
                field("Phys Invt Counting Period Type"; Rec."Phys Invt Counting Period Type")
                {
                    ToolTip = 'Specifies whether the physical inventory counting period was assigned to a stockkeeping unit or an item.';
                }
                field("Phys. Inventory"; Rec."Phys. Inventory")
                {
                    ToolTip = 'Specifies the value of the Phys. Inventory field.', Comment = '%';
                }
                field("Qty. (Absolute)"; Rec."Qty. (Absolute)")
                {
                    ToolTip = 'Specifies the value of the Qty. (Absolute) field.', Comment = '%';
                }
                field("Qty. (Absolute, Base)"; Rec."Qty. (Absolute, Base)")
                {
                    ToolTip = 'Specifies the quantity expressed as an absolute (positive) number, in the base unit of measure.';
                }
                field("Qty. (Base)"; Rec."Qty. (Base)")
                {
                    ToolTip = 'Specifies the value of the Qty. (Base) field.', Comment = '%';
                }
                field("Qty. (Calculated)"; Rec."Qty. (Calculated)")
                {
                    ToolTip = 'Specifies the quantity of the bin item that is calculated when you use the function, Calculate Inventory, in the Whse. Physical Inventory Journal.';
                }
                field("Qty. (Calculated) (Base)"; Rec."Qty. (Calculated) (Base)")
                {
                    ToolTip = 'Specifies the same as for the field in the Item Journal window.';
                }
                field("Qty. (Phys. Inventory)"; Rec."Qty. (Phys. Inventory)")
                {
                    ToolTip = 'Specifies the quantity of items in the bin that you have counted.';
                }
                field("Qty. (Phys. Inventory) (Base)"; Rec."Qty. (Phys. Inventory) (Base)")
                {
                    ToolTip = 'Specifies the same as for the field in the Item Journal window.';
                }
                field("Qty. Rounding Precision"; Rec."Qty. Rounding Precision")
                {
                    ToolTip = 'Specifies the value of the Qty. Rounding Precision field.', Comment = '%';
                }
                field("Qty. Rounding Precision (Base)"; Rec."Qty. Rounding Precision (Base)")
                {
                    ToolTip = 'Specifies the value of the Qty. Rounding Precision (Base) field.', Comment = '%';
                }
                field("Qty. per Unit of Measure"; Rec."Qty. per Unit of Measure")
                {
                    ToolTip = 'Specifies the number of base units of measure in the unit of measure specified for the item on the journal line.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the number of units of the item in the adjustment (positive or negative) or the reclassification.';
                }
                field("Reason Code"; Rec."Reason Code")
                {
                    ToolTip = 'Specifies the reason code, a supplementary source code that enables you to trace the entry.';
                }
                field("Reference Document"; Rec."Reference Document")
                {
                    ToolTip = 'Specifies the value of the Reference Document field.', Comment = '%';
                }
                field("Reference No."; Rec."Reference No.")
                {
                    ToolTip = 'Specifies the value of the Reference No. field.', Comment = '%';
                }
                field("Registering Date"; Rec."Registering Date")
                {
                    ToolTip = 'Specifies the date the line is registered.';
                }
                field("Registering No. Series"; Rec."Registering No. Series")
                {
                    ToolTip = 'Specifies the value of the Registering No. Series field.', Comment = '%';
                }
                field("Serial No."; Rec."Serial No.")
                {
                    ToolTip = 'Specifies the same as for the field in the Item Journal window.';
                }
                field("Source Code"; Rec."Source Code")
                {
                    ToolTip = 'Specifies the value of the Source Code field.', Comment = '%';
                }
                field("Source Document"; Rec."Source Document")
                {
                    ToolTip = 'Specifies the value of the Source Document field.', Comment = '%';
                }
                field("Source Line No."; Rec."Source Line No.")
                {
                    ToolTip = 'Specifies the value of the Source Line No. field.', Comment = '%';
                }
                field("Source No."; Rec."Source No.")
                {
                    ToolTip = 'Specifies the value of the Source No. field.', Comment = '%';
                }
                field("Source Subline No."; Rec."Source Subline No.")
                {
                    ToolTip = 'Specifies the value of the Source Subline No. field.', Comment = '%';
                }
                field("Source Subtype"; Rec."Source Subtype")
                {
                    ToolTip = 'Specifies the value of the Source Subtype field.', Comment = '%';
                }
                field("Source Type"; Rec."Source Type")
                {
                    ToolTip = 'Specifies the value of the Source Type field.', Comment = '%';
                }
                field(SystemCreatedAt; Rec.SystemCreatedAt)
                {
                    ToolTip = 'Specifies the value of the SystemCreatedAt field.', Comment = '%';
                }
                field(SystemCreatedBy; Rec.SystemCreatedBy)
                {
                    ToolTip = 'Specifies the value of the SystemCreatedBy field.', Comment = '%';
                }
                field(SystemId; Rec.SystemId)
                {
                    ToolTip = 'Specifies the value of the SystemId field.', Comment = '%';
                }
                field(SystemModifiedAt; Rec.SystemModifiedAt)
                {
                    ToolTip = 'Specifies the value of the SystemModifiedAt field.', Comment = '%';
                }
                field(SystemModifiedBy; Rec.SystemModifiedBy)
                {
                    ToolTip = 'Specifies the value of the SystemModifiedBy field.', Comment = '%';
                }
                field("To Bin Code"; Rec."To Bin Code")
                {
                    ToolTip = 'Specifies the code of the bin to which the item on the journal line will be moved.';
                }
                field("To Zone Code"; Rec."To Zone Code")
                {
                    ToolTip = 'Specifies the code of the zone to which the item on the journal line will be moved.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ToolTip = 'Specifies how each unit of the item or resource is measured, such as in pieces or hours. By default, the value in the Base Unit of Measure field on the item or resource card is inserted.';
                }
                field("User ID"; Rec."User ID")
                {
                    ToolTip = 'Specifies the ID of the user who posted the entry, to be used, for example, in the change log.';
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ToolTip = 'Specifies the variant of the item on the line.';
                }
                field("Warranty Date"; Rec."Warranty Date")
                {
                    ToolTip = 'Specifies the last day of warranty for the item on the line.';
                }
                field(Weight; Rec.Weight)
                {
                    ToolTip = 'Specifies the weight of one item unit when measured in the specified unit of measure.';
                }
                field("Whse. Document Line No."; Rec."Whse. Document Line No.")
                {
                    ToolTip = 'Specifies the value of the Whse. Document Line No. field.', Comment = '%';
                }
                field("Whse. Document No."; Rec."Whse. Document No.")
                {
                    ToolTip = 'Specifies the warehouse document number of the journal line.';
                }
                field("Whse. Document Type"; Rec."Whse. Document Type")
                {
                    ToolTip = 'Specifies the value of the Whse. Document Type field.', Comment = '%';
                }
                field("Zone Code"; Rec."Zone Code")
                {
                    ToolTip = 'Specifies the zone code where the bin on this line is located.';
                }
            }
        }
    }
}
