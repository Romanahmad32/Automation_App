namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Stellschrauben des Versands (Section "EmailVersand" in appsettings.json).
/// Die Zugangsdaten stehen bewusst <b>nicht</b> hier: Gesendet wird über
/// dasselbe Postfach, das auch überwacht wird (MailboxConfigStore) — ein
/// zweiter Satz Zugangsdaten wäre eine zweite Stelle, die veraltet.
/// </summary>
public sealed class EmailVersandOptions
{
    public const string SectionName = "EmailVersand";

    /// <summary>
    /// SMTP-Server, falls die Ableitung aus dem IMAP-Host nicht passt.
    /// Leer = abgeleitet (siehe <see cref="SmtpZugang.Aus"/>). Nötig z. B. für
    /// private Outlook.com-Konten, die über smtp-mail.outlook.com senden.
    /// </summary>
    public string SmtpHost { get; init; } = string.Empty;

    /// <summary>
    /// Submission-Port. 587 (STARTTLS) ist der Standardweg beider Anbieter;
    /// 465 (sofort verschluesselt) geht auch — der Client waehlt den Weg am
    /// Port (<see cref="MailKit.Security.SecureSocketOptions.Auto"/>).
    /// </summary>
    public int SmtpPort { get; init; } = 587;

    /// <summary>
    /// Ob die gesendete Nachricht zusätzlich per IMAP in den Ordner "Gesendet"
    /// gelegt wird. Null = selbst entscheiden: Gmail legt über SMTP gesendete
    /// Mails selbst ab, eine Kopie wäre dort ein Duplikat.
    /// </summary>
    public bool? KopieInGesendet { get; init; }

    /// <summary>
    /// Obergrenze aller Anhänge zusammen. Die üblichen Postfächer weisen
    /// größere Nachrichten ab — besser vorher im Klartext melden, als nach
    /// einer Minute Upload eine englische Serverantwort zu zeigen.
    /// </summary>
    public int MaxAnhangGesamtMb { get; init; } = 20;
}
