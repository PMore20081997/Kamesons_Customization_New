table 99991 "Decant Details"
{
    Caption = 'Decant Details';
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Journal Template Name"; Code[10])
        {
            DataClassification = ToBeClassified;
            TableRelation = "Warehouse Journal Template";

        }
        field(2; "Journal Batch Name"; Code[10])
        {
            DataClassification = ToBeClassified;
            TableRelation = "Warehouse Journal Batch".Name WHERE("Journal Template Name" = FIELD("Journal Template Name"));
        }
        field(3; "Line No."; Integer)
        {
            DataClassification = ToBeClassified;
            //AutoIncrement = true;
        }
        field(4; "Location Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            TableRelation = Location;
        }
        field(5; "From Zone Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            TableRelation = Zone.Code WHERE("Location Code" = FIELD("Location Code"));
        }
        field(6; "From Bin Code"; Code[20])
        {
            DataClassification = ToBeClassified;
            TableRelation = Bin.Code;
        }
        field(7; "Item No."; Code[20])
        {
            DataClassification = ToBeClassified;
            TableRelation = Item."No.";
        }
        field(8; Description; Text[100])
        {
            DataClassification = ToBeClassified;
            TableRelation = Item.Description where("No." = field("Item No."));
            Editable = false;
        }
        field(9; Quantity; Decimal)
        {
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(10; "To Zone Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            TableRelation = Zone.Code WHERE("Location Code" = FIELD("Location Code"));
        }
        field(11; "To Bin Code"; Code[20])
        {
            DataClassification = ToBeClassified;
            TableRelation = IF ("To Zone Code" = FILTER('')) Bin.Code WHERE("Location Code" = FIELD("Location Code"))
            ELSE
            IF ("To Zone Code" = FILTER(<> '')) Bin.Code WHERE("Location Code" = FIELD("Location Code"),
                                                                                              "Zone Code" = FIELD("To Zone Code"));
        }
        field(12; "Package No."; Code[20])
        {
            DataClassification = ToBeClassified;
        }
        field(13; "New Package No."; Code[20])
        {
            DataClassification = ToBeClassified;

            trigger OnValidate()
            var
                L_DecantDetails: Record "Decant Details";
            begin
                L_DecantDetails.Reset();
                L_DecantDetails.SetRange("Journal Batch Name", Rec."Journal Batch Name");
                L_DecantDetails.SetRange("Location Code", Rec."Location Code");
                L_DecantDetails.SetRange("Item No.", Rec."Item No.");
                L_DecantDetails.SetRange("Manufacturer Code", Rec."Manufacturer Code");
                L_DecantDetails.SetRange("New Package No.", Rec."New Package No.");
                if not L_DecantDetails.IsEmpty then
                    Error('New Package No. already scanned %1', Rec."New Package No.");
            end;
        }
        field(14; "Lot No."; Code[50])
        {
            DataClassification = ToBeClassified;
        }
        field(15; "To Qty."; Decimal)
        {
            DataClassification = ToBeClassified;
            DecimalPlaces = 0 : 5;
        }
        field(16; "Variant Code"; Code[20])
        {
            DataClassification = ToBeClassified;
        }
        field(17; "Expiry Date"; Date)
        {
            DataClassification = ToBeClassified;
        }
        field(18; "Reason Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            TableRelation = "Reason Code";
        }
        field(19; "Available Qty. to Take"; Decimal)
        {
            DataClassification = ToBeClassified;
            Caption = 'Available Qty. to Take';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(20; "To Location Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            Caption = 'To Location Code';
            TableRelation = Location;
        }
        field(21; "Manufacturer Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            Caption = 'Manufacturer Code';
            TableRelation = "Item Manufacturer Table"."Manufacturer Code" WHERE("Item No" = FIELD("Item No."));

            trigger OnValidate()
            var
                ItemManufacturer: Record "Item Manufacturer Table";
            begin
                if "Manufacturer Code" <> '' then begin
                    if ItemManufacturer.Get("Item No.", "Manufacturer Code") then
                        "Qty Per Tote" := ItemManufacturer."Qty per Tote"
                    else
                        "Qty Per Tote" := 0;

                    if ("Qty Per Tote" > 0) and ("Number of Totes" > 0) then
                        "To Qty." := "Qty Per Tote" * "Number of Totes"
                    else
                        "To Qty." := 0;
                end else begin
                    "Qty Per Tote" := 0;
                    "To Qty." := 0;
                end;
            end;
        }
        field(22; "Qty Per Tote"; Decimal)
        {
            DataClassification = ToBeClassified;
            Caption = 'Qty Per Tote';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(23; "Number of Totes"; Integer)
        {
            DataClassification = ToBeClassified;
            Caption = 'Number of Totes';
            Editable = false;
        }

        field(5407; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            TableRelation = "Item Unit of Measure".Code WHERE("Item No." = FIELD("Item No."));
        }
    }
    keys
    {
        key(PK; "Journal Template Name", "Journal Batch Name", "Line No.", "Location Code", "Lot No.", "Item No.", "From Zone Code", "From Bin Code")
        {
            Clustered = true;
        }
    }



    procedure LookupName(var CurrentJnlBatchName: Code[10]; var CurrentLocationCode: Code[10]; var DecantDetails: Record "Decant Details")
    var
        WhseJnlBatch: Record "Warehouse Journal Batch";
    begin
        Commit();
        WhseJnlBatch."Journal Template Name" := DecantDetails.GetRangeMax("Journal Template Name");
        WhseJnlBatch.Name := DecantDetails.GetRangeMax("Journal Batch Name");
        WhseJnlBatch.SetRange("Journal Template Name", WhseJnlBatch."Journal Template Name");
        if PAGE.RunModal(PAGE::"Whse. Journal Batches List", WhseJnlBatch) = ACTION::LookupOK then begin
            CurrentJnlBatchName := WhseJnlBatch.Name;
            CurrentLocationCode := WhseJnlBatch."Location Code";
            //OnLookupNameOnBeforeSetName(DecantDetails, WhseJnlBatch);
            SetName(CurrentJnlBatchName, CurrentLocationCode, DecantDetails);
        end;
    end;

    procedure SetName(CurrentJnlBatchName: Code[10]; CurrentLocationCode: Code[10]; var DecantDetails: Record "Decant Details")
    begin
        DecantDetails.FilterGroup := 2;
        DecantDetails.SetRange("Journal Batch Name", CurrentJnlBatchName);
        DecantDetails.SetRange("Location Code", CurrentLocationCode);
        DecantDetails.FilterGroup := 0;
        if DecantDetails.Find('-') then;

        //OnAfterSetName(Rec, DecantDetails);
    end;

    procedure CheckName(CurrentJnlBatchName: Code[10]; CurrentLocationCode: Code[10]; var DecantDetails: Record "Decant Details")
    var
        WhseJnlBatch: Record "Warehouse Journal Batch";
        WhseEmployee: Record "Warehouse Employee";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        //OnBeforeCheckName(CurrentJnlBatchName, CurrentLocationCode, IsHandled);
        if IsHandled then
            exit;

        WhseJnlBatch.Get(
          DecantDetails.GetRangeMax("Journal Template Name"), CurrentJnlBatchName, CurrentLocationCode);
        if (UserId <> '') and not WhseEmployee.Get(UserId, CurrentLocationCode) then
            Error(Text005, CurrentLocationCode, CurrentJnlBatchName, UserId);
    end;

    procedure OpenJnl(var CurrentJnlBatchName: Code[10]; var CurrentLocationCode: Code[10]; var DestLocationCode: Code[10]; var DecantDetails: Record "Decant Details")
    begin
        //OnBeforeOpenJnl(DecantDetails, CurrentJnlBatchName, CurrentLocationCode);

        WMSMgt.CheckUserIsWhseEmployee;
        CheckTemplateName(
          DecantDetails.GetRangeMax("Journal Template Name"), CurrentLocationCode, DestLocationCode, CurrentJnlBatchName);
        DecantDetails.FilterGroup := 2;
        DecantDetails.SetRange("Journal Batch Name", CurrentJnlBatchName);
        if CurrentLocationCode <> '' then
            DecantDetails.SetRange("Location Code", CurrentLocationCode);
        DecantDetails.FilterGroup := 0;

        //OnAfterOpenJnl(DecantDetails, CurrentJnlBatchName, CurrentLocationCode);
    end;

    procedure CheckTemplateName(CurrentJnlTemplateName: Code[10]; var CurrentLocationCode: Code[10]; var DestLocationCode: Code[10]; var CurrentJnlBatchName: Code[10])
    var
        WhseJnlBatch: Record "Warehouse Journal Batch";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        //OnBeforeCheckTemplateName(CurrentJnlTemplateName, CurrentJnlBatchName, CurrentLocationCode, IsHandled);
        if IsHandled then
            exit;

        if FindExistingBatch(CurrentJnlTemplateName, CurrentLocationCode, DestLocationCode, CurrentJnlBatchName) then
            exit;

        WhseJnlBatch.Init();
        WhseJnlBatch."Journal Template Name" := CurrentJnlTemplateName;
        WhseJnlBatch.SetupNewBatch;
        WhseJnlBatch."Location Code" := CurrentLocationCode;
        WhseJnlBatch.Name := Text002;
        WhseJnlBatch.Description := Text003;
        WhseJnlBatch.Insert(true);
        Commit();
        CurrentJnlBatchName := WhseJnlBatch.Name;
    end;

    local procedure FindExistingBatch(CurrentJnlTemplateName: Code[10]; var CurrentLocationCode: Code[10]; var DestLocationCode: Code[10]; var CurrentJnlBatchName: Code[10]): Boolean
    var
        WhseJnlBatch: Record "Warehouse Journal Batch";
        //L_Events: Codeunit Events;
        L_KamWhseSetupLookup: Codeunit "Kam Whse Setup Lookup";
    begin
        WhseJnlBatch.SetRange("Journal Template Name", CurrentJnlTemplateName);
        WhseJnlBatch.SetRange(Name, CurrentJnlBatchName);

        if IsWarehouseEmployeeLocationDirectPutAwayAndPick(CurrentLocationCode) then begin
            WhseJnlBatch.SetRange("Location Code", CurrentLocationCode);
            if not WhseJnlBatch.IsEmpty() then
                exit(true);
        end;

        WhseJnlBatch.SetRange(Name);
        CurrentLocationCode := WMSMgt.GetDefaultLocation();
        DestLocationCode := L_KamWhseSetupLookup.GetMainLocation();

        WhseJnlBatch.SetRange("Location Code", CurrentLocationCode);

        if WhseJnlBatch.FindFirst then begin
            CurrentJnlBatchName := WhseJnlBatch.Name;
            exit(true);
        end;

        WhseJnlBatch.SetRange("Location Code");

        if WhseJnlBatch.FindSet then begin
            repeat
                if IsWarehouseEmployeeLocationDirectPutAwayAndPick(WhseJnlBatch."Location Code") then begin
                    CurrentLocationCode := WhseJnlBatch."Location Code";
                    CurrentJnlBatchName := WhseJnlBatch.Name;
                    exit(true);
                end;
            until WhseJnlBatch.Next() = 0;
        end;

        exit(false);
    end;

    local procedure IsWarehouseEmployeeLocationDirectPutAwayAndPick(LocationCode: Code[10]): Boolean
    var
        Location: Record Location;
        WarehouseEmployee: Record "Warehouse Employee";
    begin
        if Location.Get(LocationCode) and Location."Directed Put-away and Pick" then
            exit(WarehouseEmployee.Get(UserId, Location.Code));

        exit(false);
    end;

    procedure TemplateSelection(PageID: Integer; PageTemplate: Option Adjustment,"Phys. Inventory",Reclassification; var DecantDetails: Record "Decant Details"; var JnlSelected: Boolean)
    var
        WhseJnlTemplate: Record "Warehouse Journal Template";
    begin
        JnlSelected := true;

        WhseJnlTemplate.Reset();
        if not OpenFromBatch then
            WhseJnlTemplate.SetRange("Page ID", PageID);
        WhseJnlTemplate.SetRange(Type, PageTemplate);
        //OnTemplateSelectionOnAfterSetFilters(Rec, WhseJnlTemplate, OpenFromBatch);

        case WhseJnlTemplate.Count of
            0:
                begin
                    WhseJnlTemplate.Init();
                    WhseJnlTemplate.Validate(Type, PageTemplate);
                    WhseJnlTemplate.Validate("Page ID");
                    WhseJnlTemplate.Name := Format(WhseJnlTemplate.Type, MaxStrLen(WhseJnlTemplate.Name));
                    WhseJnlTemplate.Description := StrSubstNo(Text001, WhseJnlTemplate.Type);
                    WhseJnlTemplate.Insert();
                    Commit();
                end;
            1:
                WhseJnlTemplate.FindFirst;
            else
                JnlSelected := PAGE.RunModal(0, WhseJnlTemplate) = ACTION::LookupOK;
        end;
        if JnlSelected then begin
            DecantDetails.FilterGroup := 2;
            DecantDetails.SetRange("Journal Template Name", WhseJnlTemplate.Name);
            DecantDetails.FilterGroup := 0;
            if OpenFromBatch then begin
                DecantDetails."Journal Template Name" := '';
                PAGE.Run(WhseJnlTemplate."Page ID", DecantDetails);
            end;
        end;
    end;

    var
        Text005: Label 'The location %1 of warehouse journal batch %2 is not enabled for user %3.';
        WMSMgt: Codeunit "WMS Management";
        Text002: Label 'DEFAULT';
        Text003: Label 'Default Journal';
        OpenFromBatch: Boolean;
        Text001: Label '%1 Journal';
        temptable: Record "Lot Bin Buffer";

}
