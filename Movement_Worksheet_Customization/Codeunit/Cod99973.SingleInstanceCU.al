// namespace Kamesons_Customization.Kamesons_Customization;

// codeunit 99973 SingleInstanceCU
// {
//     SingleInstance = true;

//     procedure ExecutedFromCustomMovementWorksheet(P_Flag: Boolean)
//     begin
//         Clear(G_ExecutedFromCustomMovement);
//         G_ExecutedFromCustomMovement := P_Flag;
//     end;

//     procedure IsExecutedFromCustomMovement(): Boolean
//     begin
//         exit(G_ExecutedFromCustomMovement);
//     end;

//     var
//         G_ExecutedFromCustomMovement: Boolean;
// }
