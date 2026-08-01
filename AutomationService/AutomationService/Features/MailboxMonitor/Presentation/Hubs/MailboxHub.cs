using Microsoft.AspNetCore.SignalR;

namespace AutomationService.Features.MailboxMonitor.Presentation.Hubs;

/// <summary>
/// Push-Kanal für die Postfach-Überwachung. Der Hub selbst hat keine
/// aufrufbaren Methoden — er dient nur als Verbindungspunkt, über den der
/// <see cref="HostedServices.MailboxMonitorService"/> die Oberfläche
/// benachrichtigt, sobald sich der Verbindungsstatus ändert
/// (<c>statusChanged</c>) oder eine neue Zentralruf-Antwort erfasst wurde
/// (<c>replyReceived</c>). Die Oberfläche holt den konkreten Stand anschließend
/// per REST nach, damit der Store die einzige Datenquelle bleibt.
/// </summary>
public sealed class MailboxHub : Hub
{
    /// <summary>Neue Zentralruf-Antwort erfasst — der Client lädt die Treffer per REST nach.</summary>
    public const string ReplyReceivedEvent = "replyReceived";

    /// <summary>Verbindungsstatus des Monitors geändert — der Client lädt den Status per REST nach.</summary>
    public const string StatusChangedEvent = "statusChanged";
}
