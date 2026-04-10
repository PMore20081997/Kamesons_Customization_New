// report 99991 CreateDecantWhseReclassAndPost
// {
//     Caption = 'CreateDecantWhseReclassAndPost';
//     ProcessingOnly = true;
//     dataset
//     {
//         dataitem("Lot No. Information"; "Lot No. Information")
//         {
//             trigger OnAfterGetRecord()
//             begin
//                 G_CreateDecantWhseReclassAndPost.CreateWarehouseReclassJournals("Lot No. Information");
//             end;
//         }
//     }
//     requestpage
//     {
//         layout
//         {
//             area(Content)
//             {
//                 group(GroupName)
//                 {
//                 }
//             }
//         }
//         actions
//         {
//             area(Processing)
//             {
//             }
//         }
//     }
//     var
//         G_CreateDecantWhseReclassAndPost: Codeunit CreateDecantWhseReclassAndPost;

// }
