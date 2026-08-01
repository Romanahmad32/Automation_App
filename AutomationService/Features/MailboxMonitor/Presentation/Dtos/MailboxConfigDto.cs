using AutomationService.Features.MailboxMonitor.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Presentation.Dtos;

/// <summary>
/// Der Postfach-Zugang, wie ihn die Einstellungsmaske anzeigt. Das App-Passwort
/// wird bewusst nicht zurückgegeben (Geheimnis) — stattdessen meldet
/// <see cref="AppPasswordSet"/>, ob bereits eines hinterlegt ist. Für die
/// Microsoft-Anmeldung meldet <see cref="MicrosoftAccount"/> das angemeldete
/// Konto (null = nicht angemeldet) und <see cref="MicrosoftAuthAvailable"/>, ob
/// die Anmeldung überhaupt möglich ist (Azure-Client-ID hinterlegt).
/// </summary>
public sealed record MailboxConfigDto(
    bool Enabled,
    string AuthMethod,
    string Host,
    int Port,
    bool UseSsl,
    string Username,
    bool AppPasswordSet,
    bool MicrosoftAuthAvailable,
    string? MicrosoftAccount,
    string Folder,
    string SubjectFilter)
{
    public static MailboxConfigDto From(
        MailboxOptions options,
        bool microsoftAuthAvailable,
        string? microsoftAccount) => new(
        options.Enabled,
        options.AuthMethod.ToString(),
        options.Host,
        options.Port,
        options.UseSsl,
        options.Username,
        !string.IsNullOrWhiteSpace(options.AppPassword),
        microsoftAuthAvailable,
        microsoftAccount,
        options.Folder,
        options.SubjectFilter);
}
