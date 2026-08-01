namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Die vom Nutzer in den Einstellungen änderbare Teilmenge der
/// <see cref="MailboxOptions"/> (Postfach-Zugang). Die Robustheits-Stellschrauben
/// (IDLE-Intervall, Reconnect-Backoff, Nachscan-Anzahl) und die Azure-Client-ID
/// bleiben bewusst nur über appsettings.json konfigurierbar und werden hier
/// unverändert übernommen.
/// </summary>
public sealed record MailboxConfigUpdate(
    bool Enabled,
    MailboxAuthMethod AuthMethod,
    string Host,
    int Port,
    bool UseSsl,
    string Username,
    // null bedeutet "unverändert lassen": Das Frontend kennt das gespeicherte
    // App-Passwort nicht und schickt es nur mit, wenn es neu gesetzt wird.
    string? AppPassword,
    string Folder,
    string SubjectFilter)
{
    /// <summary>
    /// Wendet die Änderung auf die aktuell gültige Konfiguration an und liefert
    /// eine neue, vollständige <see cref="MailboxOptions"/>. Leere Pflichtwerte
    /// (Host, Folder) fallen auf den bisherigen Wert zurück; ein null-Passwort
    /// lässt das gespeicherte unberührt; die Tuning-Felder bleiben erhalten.
    /// </summary>
    public MailboxOptions ApplyTo(MailboxOptions current) => new()
    {
        Enabled = Enabled,
        AuthMethod = AuthMethod,
        Host = string.IsNullOrWhiteSpace(Host) ? current.Host : Host.Trim(),
        Port = Port > 0 ? Port : current.Port,
        UseSsl = UseSsl,
        Username = Username.Trim(),
        AppPassword = AppPassword is null ? current.AppPassword : AppPassword.Trim(),
        Folder = string.IsNullOrWhiteSpace(Folder) ? current.Folder : Folder.Trim(),
        SubjectFilter = SubjectFilter.Trim(),
        MicrosoftClientId = current.MicrosoftClientId,
        IdleRefreshMinutes = current.IdleRefreshMinutes,
        ReconnectInitialSeconds = current.ReconnectInitialSeconds,
        ReconnectMaxSeconds = current.ReconnectMaxSeconds,
        InitialScanCount = current.InitialScanCount,
    };
}
