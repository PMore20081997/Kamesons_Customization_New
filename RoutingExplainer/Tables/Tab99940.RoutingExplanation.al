namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;

/// <summary>
/// TEMPORARY buffer behind page 99941 "Why This Happened?".
///
/// Nothing here is ever persisted - the page declares SourceTableTemporary,
/// so every Explain run clears and refills the buffer. There is no cleanup
/// job and no data footprint.
///
/// One record per "fact row" the screen shows. "Row Type" says which section
/// of the screen the row belongs to, so a single table drives both repeaters
/// without extra tables:
///
///   Header    - exactly one row, carries the user input plus the verdict
///   BinFact   - one row per relevant bin (on hand / min / max / expiry)
///   Activity  - one row per recent document line for this item
/// </summary>
table 99940 "Routing Explanation NDPP"
{
    Caption = 'Routing Explanation';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = CustomerContent;
        }
        field(2; "Row Type"; Option)
        {
            Caption = 'Row Type';
            OptionMembers = Header,BinFact,Activity;
            OptionCaption = 'Header,Bin Fact,Activity';
            DataClassification = CustomerContent;
        }

        // ---------- User input (Header row) ----------
        field(10; Process; Enum "Explained Process NDPP")
        {
            Caption = 'Process';
            DataClassification = CustomerContent;
        }
        field(11; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item."No.";
        }
        field(12; "Item Barcode"; Code[50])
        {
            Caption = 'Item Barcode';
            DataClassification = CustomerContent;
        }
        field(13; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(14; "Routing Type"; Enum "Item Routing Type NDPP")
        {
            Caption = 'Routing Type';
            DataClassification = CustomerContent;
        }
        field(15; "Bin Code"; Code[20])
        {
            Caption = 'Bin Code';
            DataClassification = CustomerContent;
        }
        field(16; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            DataClassification = CustomerContent;
            TableRelation = Location.Code;
        }

        // ---------- Verdict (Header row) ----------
        field(20; Outcome; Text[250])
        {
            Caption = 'Outcome';
            DataClassification = CustomerContent;
        }
        field(21; Explanation; Text[2048])
        {
            Caption = 'Why';
            DataClassification = CustomerContent;
        }
        field(22; "Rule Applied"; Enum "Routing Explanation Rule NDPP")
        {
            Caption = 'Rule Applied';
            DataClassification = CustomerContent;
        }
        field(23; "Evaluated At"; DateTime)
        {
            Caption = 'Evaluated At';
            DataClassification = CustomerContent;
        }
        field(24; "Target Bin Code"; Code[20])
        {
            Caption = 'Would Go To Bin';
            DataClassification = CustomerContent;
        }
        field(25; "Overflow Bin Code"; Code[20])
        {
            Caption = 'Overflow Bin';
            DataClassification = CustomerContent;
        }
        field(26; "Room Available"; Decimal)
        {
            Caption = 'Room Available';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }

        // ---------- Bin fact rows ----------
        field(30; "Fact Location Code"; Code[10])
        {
            Caption = 'Location';
            DataClassification = CustomerContent;
        }
        field(31; "Fact Bin Code"; Code[20])
        {
            Caption = 'Bin';
            DataClassification = CustomerContent;
        }
        field(32; "Bin Role"; Text[30])
        {
            Caption = 'Role';
            DataClassification = CustomerContent;
        }
        field(33; "Qty On Hand"; Decimal)
        {
            Caption = 'On Hand';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(34; "Min Qty"; Decimal)
        {
            Caption = 'Min Qty';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(35; "Max Qty"; Decimal)
        {
            Caption = 'Max Qty';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(36; "Earliest Expiry"; Date)
        {
            Caption = 'Earliest Expiry';
            DataClassification = CustomerContent;
        }
        field(37; "Latest Expiry"; Date)
        {
            Caption = 'Latest Expiry';
            DataClassification = CustomerContent;
        }
        field(38; "Qty In Flight"; Decimal)
        {
            Caption = 'In Flight';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(39; "Empty Totes"; Integer)
        {
            Caption = 'Empty Totes';
            DataClassification = CustomerContent;
        }
        field(40; "Qty Per Tote"; Decimal)
        {
            Caption = 'Qty per Tote';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }

        // ---------- Activity rows ----------
        field(50; "Activity Date"; Date)
        {
            Caption = 'Date';
            DataClassification = CustomerContent;
        }
        field(51; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            DataClassification = CustomerContent;
        }
        field(52; "Activity Qty"; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(53; "Activity Bin Code"; Code[20])
        {
            Caption = 'Bin';
            DataClassification = CustomerContent;
        }
        field(54; "Activity Description"; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(55; "Activity Expiry"; Date)
        {
            Caption = 'Expiry Date';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(ByType; "Row Type", "Entry No.")
        {
        }
    }

    /// <summary>
    /// Appends a row of the given type, ready to populate. Callers set the
    /// type-specific fields then call Insert(). Entry No. continues from the
    /// highest already in the buffer, so Header / BinFact / Activity rows
    /// interleave safely.
    /// </summary>
    procedure InitRow(var Buffer: Record "Routing Explanation NDPP" temporary; RowType: Option Header,BinFact,Activity)
    var
        NextNo: Integer;
    begin
        NextNo := 1;
        Buffer.Reset();
        if Buffer.FindLast() then
            NextNo := Buffer."Entry No." + 1;

        Buffer.Init();
        Buffer."Entry No." := NextNo;
        Buffer."Row Type" := RowType;
    end;
}
