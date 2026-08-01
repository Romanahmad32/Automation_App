namespace AutomationService.Features.MailboxMonitor.Presentation.Dtos;

/// <summary>Statusanzeige der Postfach-Überwachung für die Oberfläche.</summary>
public sealed record MailboxStatusDto(
    bool Enabled,
    bool Configured,
    bool Connected,
    bool IdleSupported,
    DateTimeOffset? LastConnectedAt,
    DateTimeOffset? LastReplyAt,
    string? LastError,
    int ReceivedCount,
    int PendingCount);
