namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;

tableextension 99956 Bin_Ext extends Bin
{
    fields
    {
        field(99981; "Bulk"; Boolean)
        {
            Caption = 'Bulk';
            DataClassification = ToBeClassified;

            trigger OnValidate()
            begin
                if Rec.Bulk then
                    EnsureNoOtherFlagSet(Rec.FieldCaption(Bulk));
            end;
        }
        field(99982; "Static"; Boolean)
        {
            Caption = 'Static';
            DataClassification = ToBeClassified;

            trigger OnValidate()
            begin
                if Rec."Static" then
                    EnsureNoOtherFlagSet(Rec.FieldCaption("Static"));
            end;
        }
        field(99983; "Flowrack"; Boolean)
        {
            Caption = 'Flow Rack';
            DataClassification = ToBeClassified;

            trigger OnValidate()
            begin
                if Rec.Flowrack then
                    EnsureNoOtherFlagSet(Rec.FieldCaption(Flowrack));
            end;
        }
        field(99984; "HighBay"; Boolean)
        {
            Caption = 'High Bay';
            DataClassification = ToBeClassified;

            trigger OnValidate()
            begin
                if Rec.HighBay then
                    EnsureNoOtherFlagSet(Rec.FieldCaption(HighBay));
            end;
        }
    }

    /// <summary>
    /// A bin can carry at most ONE of the routing flags (Bulk / Static / Flowrack / HighBay).
    /// Called from the OnValidate trigger of whichever flag is being turned on.
    /// </summary>
    local procedure EnsureNoOtherFlagSet(BeingEnabledCaption: Text)
    var
        ConflictingCaption: Text;
    begin
        if Rec.Bulk and (BeingEnabledCaption <> Rec.FieldCaption(Bulk)) then
            ConflictingCaption := Rec.FieldCaption(Bulk)
        else
            if Rec."Static" and (BeingEnabledCaption <> Rec.FieldCaption("Static")) then
                ConflictingCaption := Rec.FieldCaption("Static")
            else
                if Rec.Flowrack and (BeingEnabledCaption <> Rec.FieldCaption(Flowrack)) then
                    ConflictingCaption := Rec.FieldCaption(Flowrack)
                else
                    if Rec.HighBay and (BeingEnabledCaption <> Rec.FieldCaption(HighBay)) then
                        ConflictingCaption := Rec.FieldCaption(HighBay);

        if ConflictingCaption <> '' then
            Error(OnlyOneFlagErr, BeingEnabledCaption, ConflictingCaption);
    end;

    var
        OnlyOneFlagErr: Label 'Cannot enable %1 because %2 is already enabled on this bin. A bin can only carry one routing flag.', Comment = '%1 = flag being enabled; %2 = flag already enabled';
}
