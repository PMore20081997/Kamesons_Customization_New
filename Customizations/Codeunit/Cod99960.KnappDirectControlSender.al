namespace Kamesons_Customization.Kamesons_Customization;

/// <summary>
/// Thin wrapper so the KNAPP Direct Control send can be launched with
/// Codeunit.Run(). Running it in its own transaction means a KNAPP outage
/// (timeout, auth failure, bad response) cannot roll back the Item Reclass
/// Journal that has already been posted — the queue row simply stays in
/// status New and goes out on the next run.
/// </summary>
codeunit 99960 "Knapp Direct Control Sender"
{
    trigger OnRun()
    var
        DecantScreenTasklet: Codeunit DecantScreenTasklet;
    begin
        DecantScreenTasklet.SendDirectControlsToKnapp(ChannelCode);
    end;

    var
        ChannelCode: Code[20];

    procedure SetChannelCode(NewChannelCode: Code[20])
    begin
        ChannelCode := NewChannelCode;
    end;
}
