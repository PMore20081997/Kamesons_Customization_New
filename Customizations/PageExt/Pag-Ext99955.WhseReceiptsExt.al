namespace Kamesons_Customization.Kamesons_Customization;

using Microsoft.Warehouse.Document;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.Vendor;

pageextension 99955 WhseReceiptsExt extends "Warehouse Receipts"
{
    layout
    {
        addafter("No.")
        {
            field("Vendor No."; GetVendorNo())
            {
                ApplicationArea = All;
                Caption = 'Vendor No.';
                ToolTip = 'Vendor No. taken from the source Purchase Order on the first Warehouse Receipt Line.';
            }
            field("Vendor Name"; GetVendorName())
            {
                ApplicationArea = All;
                Caption = 'Vendor Name';
                ToolTip = 'Vendor Name taken from the source Purchase Order on the first Warehouse Receipt Line.';
            }
            field("Expected Delivery Date"; Rec."Expected Delivery Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Expected Delivery Date field.', Comment = '%';
            }
            field("Shipping Carrier"; Rec."Shipping Carrier")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Shipping Carrier field.', Comment = '%';
            }
        }
    }

    local procedure GetVendorNo(): Code[20]
    var
        L_WhseRcptLine: Record "Warehouse Receipt Line";
        L_PurchHeader: Record "Purchase Header";
    begin
        L_WhseRcptLine.SetRange("No.", Rec."No.");
        L_WhseRcptLine.SetRange("Source Document", L_WhseRcptLine."Source Document"::"Purchase Order");
        if not L_WhseRcptLine.FindFirst() then
            exit('');
        if L_PurchHeader.Get(L_PurchHeader."Document Type"::Order, L_WhseRcptLine."Source No.") then
            exit(L_PurchHeader."Buy-from Vendor No.");
        exit('');
    end;

    local procedure GetVendorName(): Text[100]
    var
        L_Vendor: Record Vendor;
        L_VendorNo: Code[20];
    begin
        L_VendorNo := GetVendorNo();
        if L_VendorNo = '' then
            exit('');
        if L_Vendor.Get(L_VendorNo) then
            exit(L_Vendor.Name);
        exit('');
    end;
}
