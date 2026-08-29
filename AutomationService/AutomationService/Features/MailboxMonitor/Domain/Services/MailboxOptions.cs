namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Konfiguration der Postfach-Überwachung (Section "Mailbox" in appsettings.json).
/// Der Monitor hält eine offene IMAP-Verbindung und lässt sich vom Server per
/// IDLE benachrichtigen, sobald eine Zentralruf-Antwort eintrifft — er pollt
/// also nicht im Takt.
///
/// Der Regelfall dieser Kanzlei ist ein 1&amp;1/IONOS-Postfach: imap.ionos.de,
/// Port 993, SSL, Anmeldung mit der vollständigen Adresse und dem
/// Postfach-Passwort (dort gibt es kein App-Passwort-Konzept). Bei Gmail
/// stattdessen 2-Faktor-Authentifizierung aktivieren und ein App-Passwort
/// erzeugen (https://myaccount.google.com/apppasswords) — dieses, nicht das
/// Kontopasswort, gehört in <see cref="AppPassword"/>.
/// Ist <see cref="Enabled"/> false oder fehlen Zugangsdaten, bleibt der Monitor
/// inaktiv (kein Verbindungsversuch, kein Fehler).
/// </summary>
public sealed class MailboxOptions
{
    public const string SectionName = "Mailbox";

    /// <summary>Schaltet die Überwachung an. Default aus, damit nichts ohne Zugangsdaten verbindet.</summary>
    public bool Enabled { get; init; }

    /// <summary>
    /// Anmeldeverfahren: IMAP-Passwort (1&amp;1/IONOS, Gmail) oder Microsoft-OAuth
    /// (Outlook.com, Microsoft 365). Outlook/Microsoft-Postfächer erlauben seit
    /// September 2024 kein IMAP-Passwort mehr — dort ist
    /// <see cref="MailboxAuthMethod.MicrosoftOAuth"/> der einzige Weg.
    /// </summary>
    public MailboxAuthMethod AuthMethod { get; init; } = MailboxAuthMethod.AppPassword;

    public string Host { get; init; } = "imap.ionos.de";

    public int Port { get; init; } = 993;

    /// <summary>SSL/TLS direkt beim Verbindungsaufbau (Port 993). Für IMAP über STARTTLS auf false setzen.</summary>
    public bool UseSsl { get; init; } = true;

    /// <summary>Vollständige E-Mail-Adresse des Postfachs; zugleich der IMAP-Benutzername.</summary>
    public string Username { get; init; } = string.Empty;

    /// <summary>
    /// Passwort für die IMAP-Anmeldung: bei 1&amp;1/IONOS das Postfach-Passwort,
    /// bei Gmail das App-Passwort (nicht das Kontopasswort). Bei Microsoft-OAuth
    /// ungenutzt. Auf Platte liegt es DPAPI-verschlüsselt (<see cref="PasswortSchutz"/>).
    /// </summary>
    public string AppPassword { get; init; } = string.Empty;

    /// <summary>
    /// Client-ID der (einmalig vom Entwickler angelegten) Azure-App-Registrierung
    /// für die Microsoft-Anmeldung. Nur über appsettings.json konfigurierbar;
    /// ohne sie ist keine Outlook-Anmeldung möglich. Siehe docs/OUTLOOK_SETUP.md.
    /// </summary>
    public string MicrosoftClientId { get; init; } = string.Empty;

    /// <summary>Zu überwachender Ordner. Standard ist der Posteingang.</summary>
    public string Folder { get; init; } = "INBOX";

    /// <summary>
    /// Nur Mails verarbeiten, deren Betreff diese Zeichenkette enthält
    /// (Groß-/Kleinschreibung egal). Leer = alle Mails durch den Parser schicken.
    /// </summary>
    public string SubjectFilter { get; init; } = "Zentralruf";

    /// <summary>
    /// IMAP-IDLE muss regelmäßig erneuert werden (RFC 2177 nennt 29 Minuten als
    /// Obergrenze). 9 Minuten ist ein robuster, gängiger Wert.
    /// </summary>
    public int IdleRefreshMinutes { get; init; } = 9;

    /// <summary>Wartezeit vor dem ersten Reconnect-Versuch nach einem Verbindungsabbruch.</summary>
    public int ReconnectInitialSeconds { get; init; } = 5;

    /// <summary>Obergrenze für das exponentielle Backoff zwischen Reconnect-Versuchen.</summary>
    public int ReconnectMaxSeconds { get; init; } = 300;

    /// <summary>
    /// Wie viele der jüngsten Nachrichten beim (Wieder-)Verbinden einmalig
    /// durchgesehen werden, damit eine Antwort, die während eines kurzen
    /// Verbindungsausfalls eintraf, nicht übersehen wird.
    /// </summary>
    public int InitialScanCount { get; init; } = 20;

    /// <summary>
    /// True, wenn genug Angaben für einen Verbindungsversuch vorliegen. Bei
    /// Microsoft-OAuth genügt Host + Benutzername — ob eine gültige Anmeldung
    /// (Token) vorliegt, zeigt sich erst beim Verbinden.
    /// </summary>
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Host)
        && !string.IsNullOrWhiteSpace(Username)
        && (AuthMethod == MailboxAuthMethod.MicrosoftOAuth
            || !string.IsNullOrWhiteSpace(AppPassword));
}
