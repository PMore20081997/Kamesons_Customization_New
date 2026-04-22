table 99971 "Replenishment Worksheet"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Line No."; Integer)
        {
            DataClassification = ToBeClassified;

        }
        field(2; "Item No."; Code[20])
        {
            TableRelation = Item."No.";
        }
        field(3; Description; Text[100])
        {
            Editable = false;
        }
        field(4; "Unit of Measure Code"; Code[10])
        {
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
            Editable = false;
        }
        field(5; "Variant Code"; Code[10])
        {
            // TableRelation = "Item Variant".Code where("Item No." = field("Item No."), Priority = filter(> 0));
            Caption = 'From Variant';

            // trigger OnValidate()
            // var
            //     L_Availabletotake: Decimal;
            //     L_BinContent: Record "Bin Content";
            //     L_ReplenishmentReport: Report "Cal _Bin Replenishment New";
            //     CodeUnit_ReplenishmentWorksheet: Codeunit "Replenishment Worksheet";
            //     TransferLineQty: Decimal;
            //     L_ReplenishmentWorksheet: Record "Replenishment Worksheet";
            //     ExistQty: Decimal;
            // begin
            //     if Rec."Qty to Move" <> 0 then begin
            //         Rec.TestField("From Location Code");
            //         if Rec."Qty to Move" > Rec."Demand Quantity" then
            //             Error('Qty. to Move should not be greater than Replenishment Qty. %1', Rec."Demand Quantity");

            //         #Region Check Availibility qty++++
            //         Clear(L_Availabletotake);
            //         L_BinContent.Reset();
            //         L_BinContent.SetRange("Location Code", Rec."From Location Code");
            //         L_BinContent.SetRange("Item No.", Rec."Item No.");
            //         L_BinContent.SetRange("Variant Code", Rec."Variant Code"); //From Variant Code+++
            //         L_BinContent.SetFilter("Quantity (Base)", '>%1', 0);
            //         //L_BinContent.SetRange("Daily Priority Exist", true);
            //         if L_BinContent.FindSet() then begin
            //             repeat
            //                 // if L_ReplenishmentReport.UseForReplenishment(L_BinContent) then begin
            //                 //     L_Availabletotake := L_Availabletotake + L_BinContent.CalcQtyAvailToTakeUOM();
            //                 // end;
            //             until L_BinContent.Next() = 0;
            //             if L_Availabletotake <= 0 then
            //                 L_Availabletotake := 0;

            //             //calculate already exist qty in Replenishment worksheet++
            //             Clear(ExistQty);
            //             Clear(L_ReplenishmentWorksheet);
            //             L_ReplenishmentWorksheet.SetRange("Item No.", Rec."Item No.");
            //             L_ReplenishmentWorksheet.SetRange("Variant Code", Rec."Variant Code");
            //             L_ReplenishmentWorksheet.SetRange("From Location Code", Rec."From Location Code");
            //             //L_ReplenishmentWorksheet.SetRange("Posting Date", Rec."Posting Date");
            //             L_ReplenishmentWorksheet.SetRange("Batch Name", Rec."Batch Name");
            //             L_ReplenishmentWorksheet.SetFilter("Line No.", '<>%1', Rec."Line No.");
            //             if L_ReplenishmentWorksheet.FindSet() then
            //                 repeat
            //                     ExistQty := ExistQty + L_ReplenishmentWorksheet."Qty to Move";
            //                 until L_ReplenishmentWorksheet.Next() = 0;
            //             if ExistQty <= 0 then
            //                 ExistQty := 0;

            //             //total Available++
            //             L_Availabletotake := L_Availabletotake - ExistQty;
            //             if L_Availabletotake < 0 then
            //                 L_Availabletotake := 0;

            //             #Region Error Message++    
            //             if L_Availabletotake = 0 then
            //                 Error('Quantity not available in Bincotent. Item: "%1", Variant: "%2", Location: "%3"', Rec."Item No.", Rec."Variant Code", Rec."From Location Code");

            //             if L_Availabletotake < Rec."Qty to Move" then
            //                 Error('You cannot enter more than Available Qty.: "%1"', L_Availabletotake);
            //             #EndRegion Error Message++ 

            //         end else
            //             Error('The field From Location Code contains a value (%1) that cannot be found in the related table (Bin Content).', Rec."From Location Code");
            //         #EndRegion Check Availibility qty++++
            //     end;
            // end;
        }
        field(6; "System Quantity"; Decimal)
        {
            Caption = 'Available Quantity';
            Editable = false;
        }
        field(7; "Available Qty"; Decimal)
        {

        }
        field(8; "Demand Quantity"; Decimal)
        {
            Caption = 'Replenishment Qty.';
        }
        field(9; "Qty to Move"; Decimal)
        {
            trigger OnValidate()
            var
                L_Availabletotake: Decimal;
                L_BinContent: Record "Bin Content";
                L_ReplenishmentReport: Report "Cal _Bin Replenishment New";
                CodeUnit_ReplenishmentWorksheet: Codeunit "Replenishment Worksheet";
                TransferLineQty: Decimal;
                L_ReplenishmentWorksheet: Record "Replenishment Worksheet";
                ExistQty: Decimal;
            begin
                // if Rec."Qty to Move" <> 0 then begin
                //     Rec.TestField("From Location Code");
                //     // if L_ReplenishmentReport.GetVariantSetup(Rec."Item No.") then
                //     //     Rec.TestField("Variant Code"); //From Variant Code+++

                //     //+++
                //     if Rec."Qty to Move" > Rec."Demand Quantity" then
                //         Error('Qty. to Move should not be greater than Replenishment Qty. %1', Rec."Demand Quantity");

                //     #Region Check Availability qty++++
                //     Clear(L_Availabletotake);
                //     L_BinContent.Reset();
                //     L_BinContent.SetRange("Location Code", Rec."From Location Code");
                //     L_BinContent.SetRange("Item No.", Rec."Item No.");
                //     L_BinContent.SetRange("Variant Code", Rec."Variant Code"); //From Variant Code+++
                //     L_BinContent.SetFilter("Quantity (Base)", '>%1', 0);
                //     //L_BinContent.SetRange("Daily Priority Exist", true);
                //     if L_BinContent.FindSet() then begin
                //         repeat
                //             // if L_ReplenishmentReport.UseForReplenishment(L_BinContent) then begin
                //             //     L_Availabletotake := L_Availabletotake + L_BinContent.CalcQtyAvailToTakeUOM();
                //             // end;
                //         until L_BinContent.Next() = 0;
                //         if L_Availabletotake <= 0 then
                //             L_Availabletotake := 0;

                //         //calculate already exist qty in Replenishment worksheet++
                //         Clear(ExistQty);
                //         Clear(L_ReplenishmentWorksheet);
                //         L_ReplenishmentWorksheet.SetRange("Item No.", Rec."Item No.");
                //         L_ReplenishmentWorksheet.SetRange("Variant Code", Rec."Variant Code");
                //         L_ReplenishmentWorksheet.SetRange("From Location Code", Rec."From Location Code");
                //         //L_ReplenishmentWorksheet.SetRange("Posting Date", Rec."Posting Date");
                //         L_ReplenishmentWorksheet.SetRange("Batch Name", Rec."Batch Name");
                //         L_ReplenishmentWorksheet.SetFilter("Line No.", '<>%1', Rec."Line No.");
                //         if L_ReplenishmentWorksheet.FindSet() then
                //             repeat
                //                 ExistQty := ExistQty + L_ReplenishmentWorksheet."Qty to Move";
                //             until L_ReplenishmentWorksheet.Next() = 0;
                //         if ExistQty <= 0 then
                //             ExistQty := 0;

                //         //total Available++
                //         L_Availabletotake := L_Availabletotake - ExistQty;
                //         if L_Availabletotake < 0 then
                //             L_Availabletotake := 0;

                //         #Region Error Message++  
                //         if L_Availabletotake = 0 then
                //             Error('Quantity not available in Bincotent. Item: "%1", Variant: "%2", Location: "%3"', Rec."Item No.", Rec."Variant Code", Rec."From Location Code");

                //         if L_Availabletotake < Rec."Qty to Move" then
                //             Error('You cannot enter more than Available Qty.: "%1"', L_Availabletotake);
                //         #EndRegion Error Message++  
                //     end else
                //         Error('The field From Location Code contains a value (%1) that cannot be found in the related table (Bin Content).', Rec."From Location Code");
                //     #EndRegion Check Availability qty++++
                // end;
            end;
        }
        field(10; "Location Code"; Code[20])
        {
            TableRelation = Location;
            trigger OnValidate()
            var
                L_BinContent: Record "Bin Content";
                L_Availabletotake: Decimal;
                L_ReplenishmentReport: Report "Cal _Bin Replenishment New";
                CodeUnit_ReplenishmentWorksheet: Codeunit "Replenishment Worksheet";
                TransferLineQty: Decimal;
                L_ReplenishmentWorksheet: Record "Replenishment Worksheet";
                ExistQty: Decimal;
            begin
                // if Rec."From Location Code" <> xRec."From Location Code" then begin
                //     Rec."Qty to Move" := 0;
                //     Rec."Variant Code" := ''; //From Variant+++

                //     #Region Check Availibility qty++++
                //     Clear(L_Availabletotake);
                //     L_BinContent.Reset();
                //     L_BinContent.SetRange("Location Code", Rec."From Location Code");
                //     L_BinContent.SetRange("Item No.", Rec."Item No.");
                //     L_BinContent.SetFilter("Quantity (Base)", '>%1', 0);
                //     //L_BinContent.SetRange("Daily Priority Exist", true);
                //     if L_BinContent.FindSet() then begin
                //         repeat
                //             // if L_ReplenishmentReport.UseForReplenishment(L_BinContent) then begin
                //             //     L_Availabletotake := L_Availabletotake + L_BinContent.CalcQtyAvailToTakeUOM();
                //             // end;
                //         until L_BinContent.Next() = 0;
                //         if L_Availabletotake <= 0 then
                //             L_Availabletotake := 0;

                //         //calculate already exist qty in Replenishment worksheet++
                //         Clear(ExistQty);
                //         Clear(L_ReplenishmentWorksheet);
                //         L_ReplenishmentWorksheet.SetRange("Item No.", Rec."Item No.");
                //         L_ReplenishmentWorksheet.SetRange("Variant Code", Rec."Variant Code");
                //         L_ReplenishmentWorksheet.SetRange("From Location Code", Rec."From Location Code");
                //         // L_ReplenishmentWorksheet.SetRange("Posting Date", Rec."Posting Date");
                //         L_ReplenishmentWorksheet.SetRange("Batch Name", Rec."Batch Name");
                //         L_ReplenishmentWorksheet.SetFilter("Line No.", '<>%1', Rec."Line No.");
                //         if L_ReplenishmentWorksheet.FindSet() then
                //             repeat
                //                 ExistQty := ExistQty + L_ReplenishmentWorksheet."Qty to Move";
                //             until L_ReplenishmentWorksheet.Next() = 0;
                //         if ExistQty <= 0 then
                //             ExistQty := 0;

                //         //total Available++
                //         L_Availabletotake := L_Availabletotake - ExistQty;
                //         if L_Availabletotake < 0 then
                //             L_Availabletotake := 0;

                //         #Region Error Message++
                //         if L_Availabletotake = 0 then
                //             Error('Quantity not available in Bincotent. Item: "%1", Variant: "%2", Location: "%3"', Rec."Item No.", Rec."Variant Code", Rec."From Location Code");

                //         if L_Availabletotake < Rec."Qty to Move" then
                //             Error('You cannot enter more than Available Qty.: "%1"', L_Availabletotake);
                //         #EndRegion Error Message++

                //     end else
                //         Error('The field From Location Code contains a value (%1) that cannot be found in the related table (Bin Content).', Rec."From Location Code");
                //     #EndRegion Check Availibility qty++++

                // end;
            end;
        }
        field(11; "Bin Code"; Code[20])
        {
            TableRelation = Bin where("Location Code" = field("Location Code"));
        }
        field(12; "Max. Qty."; Decimal)
        {

        }
        field(13; "From Location Code"; Code[20])
        {
            //TableRelation = Location where("Saleable Location" = const(false));
        }
        field(14; "From Bin Code"; Code[20])
        {
            TableRelation = Bin where("Location Code" = field("From Location Code"));
        }
        field(15; "Posting Date"; Date)
        {

        }
        field(16; "Template Name"; Code[10])
        {
            Caption = 'Template Name';
            TableRelation = "Item Journal Template";
        }
        field(17; "Batch Name"; Code[10])
        {
            Caption = 'Batch Name';
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("Template Name"));
        }
        field(18; "Min. Qty."; Decimal)
        {

        }
        field(19; "Action"; Option)
        {
            Caption = 'Action';
            OptionMembers = " ","Accept","Cancel";
            Editable = true;
        }
        field(20; "Top Category"; Boolean)
        {

        }
        field(21; "System-Created Entry"; Boolean)
        {
            Caption = 'System-Created Entry';
            Editable = false;
        }
        field(22; "Pick Qty"; Decimal)
        {
            //     FieldClass = FlowField;
            //     CalcFormula = sum("Warehouse Activity Line"."Qty. Outstanding (Base)" where("Location Code" = field("From Location Code"), "Item No." = field("Item No."), "Variant Code" = field("Variant Code"), "Action Type" = const(Take), "Assemble to Order" = const(false)));
        }
        field(23; "Own Log Qty."; Decimal)
        {
            // FieldClass = FlowField;
            // CalcFormula = sum("Item Ledger Entry"."Remaining Quantity" where("Item No." = field("Item No."), "Variant Code" = field("Variant Code"), "Location Code" = filter('OWN LOG.')));
        }
        field(24; "From Variant Priority"; Integer)
        {
            // FieldClass = FlowField;
            //CalcFormula = lookup("Item Variant".Priority where("Item No." = field("Item No."), Code = field("Variant Code")));
        }
        field(25; "Maufacturer Tote Max Qty."; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(26; "Totes in Bin"; Integer)
        {
            DataClassification = ToBeClassified;
        }
        field(27; "Lot No."; Code[40])
        {
            DataClassification = ToBeClassified;
        }
        field(28; "Package No."; Code[30])
        {
            DataClassification = ToBeClassified;
        }
        field(29; "Expiration Date"; Date)
        {
            DataClassification = ToBeClassified; //New
        }
        field(30; "Manufacturer Code"; Code[100])
        {
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(Key1; "Template Name", "Batch Name", "Line No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
        myInt: Integer;
        Text003: Label 'DEFAULT';
        Text004: Label 'Default Journal';

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

    procedure IsOpenedFromBatch(): Boolean
    var
        ItemJournalBatch: Record "Item Journal Batch";
        TemplateFilter: Text;
        BatchFilter: Text;
    begin
        BatchFilter := GetFilter("Batch Name");
        if BatchFilter <> '' then begin
            TemplateFilter := GetFilter("Template Name");
            if TemplateFilter <> '' then
                ItemJournalBatch.SetFilter("Journal Template Name", TemplateFilter);
            ItemJournalBatch.SetFilter(Name, BatchFilter);
            ItemJournalBatch.FindFirst();
        end;

        exit((("Batch Name" <> '') and ("Template Name" = '')) or (BatchFilter <> ''));
    end;

    procedure OpenJnl(var CurrentJnlBatchName: Code[10]; var _ReplanishmentWorksheet: Record "Replenishment Worksheet")
    begin
        CheckTemplateName(_ReplanishmentWorksheet.GetRangeMax("Template Name"), CurrentJnlBatchName);
        _ReplanishmentWorksheet.FilterGroup := 2;
        _ReplanishmentWorksheet.SetRange("Batch Name", CurrentJnlBatchName);
        _ReplanishmentWorksheet.FilterGroup := 0;
    end;

    procedure CheckTemplateName(CurrentJnlTemplateName: Code[10]; var CurrentJnlBatchName: Code[10])
    var
        ItemJnlBatch: Record "Item Journal Batch";
    begin
        ItemJnlBatch.SetRange("Journal Template Name", CurrentJnlTemplateName);
        if not ItemJnlBatch.Get(CurrentJnlTemplateName, CurrentJnlBatchName) then begin
            if not ItemJnlBatch.FindFirst() then begin
                ItemJnlBatch.Init();
                ItemJnlBatch."Journal Template Name" := CurrentJnlTemplateName;
                ItemJnlBatch.SetupNewBatch();
                ItemJnlBatch.Name := Text003;
                ItemJnlBatch.Description := Text004;
                ItemJnlBatch.Insert(true);
                Commit();
            end;
            CurrentJnlBatchName := ItemJnlBatch.Name
        end;
    end;

}