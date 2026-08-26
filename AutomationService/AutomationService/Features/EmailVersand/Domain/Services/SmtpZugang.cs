using AutomationService.Features.MailboxMonitor.Domain.Services;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der SMTP-Zugang, abgeleitet aus dem hinterlegten Postfach-Zugang
/// (REQUIREMENTS.md §4.7). Wer empfangen kann, kann auch senden — der Anwalt
/// richtet den Zugang genau einmal ein, in den Einstellungen unter
/// "Postfach-Zugang".
/// </summary>
/// <param name="Host">SMTP-Server (submission).</param>
/// <param name="Port">Submission-Port, üblicherweise 587 mit STARTTLS.</param>
/// <param name="AuthMethod">IMAP-Passwort (1&amp;1/IONOS, Gmail) oder XOAUTH2 (Microsoft).</param>
/// <param name="Absender">Adresse des Postfachs; zugleich der Absender.</param>
/// <param name="AppPasswort">Nur bei <see cref="MailboxAuthMethod.AppPassword"/> gefüllt.</param>
/// <param name="ServerLegtKopieSelbstAb">
/// True, wenn der Anbieter über SMTP gesendete Nachrichten von sich aus in
/// "Gesendet" ablegt (Gmail). Dann wäre eine eigene Kopie ein Duplikat.
/// </param>
public sealed record SmtpZugang(
    string Host,
    int Port,
    MailboxAuthMethod AuthMethod,
    string Absender,
    string AppPasswort,
    bool ServerLegtKopieSelbstAb)
{
    /// <summary>
    /// Leitet den Zugang ab, oder null, wenn kein (vollständiger) Postfach-Zugang
    /// hinterlegt ist. <paramref name="optionen"/> darf den abgeleiteten Host
    /// überschreiben — die Ableitung trifft die beiden bekannten Anbieter, nicht
    /// jeden denkbaren.
    /// </summary>
    public static SmtpZugang? Aus(MailboxOptions postfach, EmailVersandOptions optionen)
    {
        if (!postfach.IsConfigured)
        {
            return null;
        }

        var host = string.IsNullOrWhiteSpace(optionen.SmtpHost)
            ? AbgeleiteterHost(postfach.Host)
            : optionen.SmtpHost.Trim();

        return new SmtpZugang(
            host,
            optionen.SmtpPort,
            postfach.AuthMethod,
            postfach.Username.Trim(),
            postfach.AppPassword,
            IstGmail(postfach.Host));
    }

    /// <summary>
    /// Aus dem IMAP- den SMTP-Namen machen. Die verbreiteten Anbieter benennen
    /// ihre Server nach demselben Muster (imap.ionos.de/smtp.ionos.de,
    /// imap.gmail.com/smtp.gmail.com, outlook.office365.com/smtp.office365.com);
    /// alles andere bekommt das gängige "smtp."-Präfix und lässt sich per
    /// appsettings korrigieren.
    /// </summary>
    private static string AbgeleiteterHost(string imapHost)
    {
        var host = imapHost.Trim();
        if (IstGmail(host))
        {
            return "smtp.gmail.com";
        }

        if (host.EndsWith("office365.com", StringComparison.OrdinalIgnoreCase)
            || host.EndsWith("outlook.com", StringComparison.OrdinalIgnoreCase))
        {
            return "smtp.office365.com";
        }

        return host.StartsWith("imap.", StringComparison.OrdinalIgnoreCase)
            ? string.Concat("smtp.", host.AsSpan("imap.".Length))
            : host;
    }

    private static bool IstGmail(string host) =>
        host.Trim().EndsWith("gmail.com", StringComparison.OrdinalIgnoreCase)
        || host.Trim().EndsWith("googlemail.com", StringComparison.OrdinalIgnoreCase);
}
