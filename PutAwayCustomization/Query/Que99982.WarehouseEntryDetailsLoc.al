// query 99982 WarehouseEntryLotDetailsLoc
// {
//     Caption = 'WarehouseEntryLotDetails';
//     QueryType = Normal;
//     OrderBy = descending(SystemModifiedAt);

//     elements
//     {
//         dataitem(WarehouseEntry; "Warehouse Entry")
//         {
//             //DataItemTableFilter = "Source Document" = filter('P.Order');
//             column(Item_No_; "Item No.")
//             {

//             }
//             column(Location_Code; "Location Code")
//             {

//             }
//             // column(Zone_Code; "Zone Code")
//             // {

//             // }
//             column(Source_Document; "Source Document")
//             {

//             }
//             // filter(Zone_Code; "Zone Code")
//             // {

//             // }
//             column(Source_No_; "Source No.")
//             {

//             }
//             column(Source_Line_No_; "Source Line No.")
//             {

//             }

//             column(Lot_No_; "Lot No.")
//             {

//             }
//             column(Expiration_Date; "Expiration Date")
//             {

//             }
//             column(SystemModifiedAt;SystemModifiedAt)
//             {

//             }
//             column(Quantity; Quantity)
//             {
//                 Method = Sum;
//             }
//         }
//     }

//     trigger OnBeforeOpen()
//     begin

//     end;
// }
