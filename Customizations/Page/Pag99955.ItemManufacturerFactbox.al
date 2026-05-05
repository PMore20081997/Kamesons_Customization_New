namespace Kamesons_Customization.Kamesons_Customization;

page 99955 "Item Manufacturer Factbox"
{
    Caption = 'Item Manufacturer Factbox';
    PageType = ListPart;
    SourceTable = "Item Manufacturer Table";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Item No"; Rec."Item No")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field("Manufacturer code"; Rec."Manufacturer code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the manufacturer code (Manufacturer Code field from C&D).';
                }
                field("Manufacturer Name"; Rec."Manufacturer Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the manufacturer name (from C&D).';
                }
                field("Qty per Tote"; Rec."Qty per Tote")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum quantity per tote.';
                }
            }
        }
    }
}
