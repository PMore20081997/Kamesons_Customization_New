namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Structure;

tableextension 99956 Bin_Ext extends Bin
{
    fields
    {
        field(99981; "Bulk"; Boolean)
        {
            Caption = 'Bulk';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if Rec.Bulk then
                    EnsureNoOtherFlagSet(Rec.FieldCaption(Bulk));
            end;
        }
        field(99982; "Static"; Boolean)
        {
            Caption = 'Static';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if Rec."Static" then
                    EnsureNoOtherFlagSet(Rec.FieldCaption("Static"));
            end;
        }
        field(99983; "Flowrack"; Boolean)
        {
            Caption = 'Flow Rack';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if Rec.Flowrack then
                    EnsureNoOtherFlagSet(Rec.FieldCaption(Flowrack));
            end;
        }
        field(99984; "HighBay"; Boolean)
        {
            Caption = 'High Bay';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if Rec.HighBay then
                    EnsureNoOtherFlagSet(Rec.FieldCaption(HighBay));
            end;
        }
    }

    /// <summary>
    /// Routing-flag compatibility rules:
    ///   * Bulk and HighBay are EXCLUSIVE — neither may coexist with any
    ///     other routing flag on the same bin.
    ///   * Static and Flowrack MAY coexist (used for the Receive-side
    ///     GEN DECANT bin which stages both routing types). They still
    ///     cannot be combined with Bulk or HighBay.
    /// Called from the OnValidate trigger of whichever flag is being turned on.
    /// </summary>
    local procedure EnsureNoOtherFlagSet(BeingEnabledCaption: Text)
    var
        ConflictingCaption: Text;
    begin
        case BeingEnabledCaption of
            Rec.FieldCaption(Bulk):
                // Bulk is exclusive — conflicts with every other flag.
                if Rec."Static" then
                    ConflictingCaption := Rec.FieldCaption("Static")
                else
                    if Rec.Flowrack then
                        ConflictingCaption := Rec.FieldCaption(Flowrack)
                    else
                        if Rec.HighBay then
                            ConflictingCaption := Rec.FieldCaption(HighBay);
            Rec.FieldCaption(HighBay):
                // HighBay is exclusive — conflicts with every other flag.
                if Rec.Bulk then
                    ConflictingCaption := Rec.FieldCaption(Bulk)
                else
                    if Rec."Static" then
                        ConflictingCaption := Rec.FieldCaption("Static")
                    else
                        if Rec.Flowrack then
                            ConflictingCaption := Rec.FieldCaption(Flowrack);
            Rec.FieldCaption("Static"):
                // Static can coexist with Flowrack — only Bulk / HighBay conflict.
                if Rec.Bulk then
                    ConflictingCaption := Rec.FieldCaption(Bulk)
                else
                    if Rec.HighBay then
                        ConflictingCaption := Rec.FieldCaption(HighBay);
            Rec.FieldCaption(Flowrack):
                // Flowrack can coexist with Static — only Bulk / HighBay conflict.
                if Rec.Bulk then
                    ConflictingCaption := Rec.FieldCaption(Bulk)
                else
                    if Rec.HighBay then
                        ConflictingCaption := Rec.FieldCaption(HighBay);
        end;

        if ConflictingCaption <> '' then
            Error(IncompatibleFlagErr, BeingEnabledCaption, ConflictingCaption);
    end;

    var
        IncompatibleFlagErr: Label 'Cannot enable %1 because %2 is already enabled on this bin. Bulk and HighBay must each be the only routing flag; Static and Flowrack may coexist with each other but not with Bulk or HighBay.', Comment = '%1 = flag being enabled; %2 = flag already enabled';
}
