namespace Kamesons_Customization.Kamesons_Customization;
using Microsoft.Warehouse.Document;
using Microsoft.Purchases.Document;

codeunit 99976 Customize_Events
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purchases Warehouse Mgt.", OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine, '', false, false)]
    local procedure OnPurchLine2ReceiptLineOnAfterUpdateReceiptLine(var WarehouseReceiptLine: Record "Warehouse Receipt Line"; PurchaseLine: Record "Purchase Line")
    begin
        WarehouseReceiptLine."Manufacturer Code" := PurchaseLine."Manufacturer Code";
    end;
}
