using AutomationService.Features.MailboxMonitor.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Presentation.Dtos;

/// <summary>
/// Eingabe der Einstellungsmaske für den Postfach-Zugang. Ein null- oder
/// fehlendes <see cref="AppPassword"/> bedeutet "unverändert lassen" — die Maske
/// kennt das gespeicherte Passwort nicht und schickt es nur beim Neusetzen mit.
/// </summary>
public sealed record MailboxConfigUpdateDto(
    bool Enabled,
    string? AuthMethod,
    string? Host,
    int Port,
    bool UseSsl,
    string? Username,
    string? AppPassword,
    string? Folder,
    string? SubjectFilter)
{
    public MailboxConfigUpdate ToDomain() => new(
        Enabled,
        Enum.TryParse<MailboxAuthMethod>(AuthMethod, ignoreCase: true, out var method)
            ? method
            : MailboxAuthMethod.AppPassword,
        Host ?? string.Empty,
        Port,
        UseSsl,
        Username ?? string.Empty,
        AppPassword,
        Folder ?? string.Empty,
        SubjectFilter ?? string.Empty);
}
