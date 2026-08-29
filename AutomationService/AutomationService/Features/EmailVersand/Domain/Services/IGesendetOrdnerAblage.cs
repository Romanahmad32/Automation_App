using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Traegt eine gesendete Nachricht in den Ordner "Gesendet" nach (§4.7).
///
/// Naht wie <see cref="ISmtpUebergabe"/>, und aus demselben Grund: Ob der
/// Versand richtig weiterlaeuft, wenn die Kopie <b>misslingt</b>, ist eine der
/// Fragen, die man am Bestand nur erlesen kann -- der Weg dorthin fuehrt sonst
/// ueber einen echten IMAP-Server. Mit der Naht ist es ein Testfall
/// (<c>VersandwegTests</c>).
/// </summary>
public interface IGesendetOrdnerAblage
{
    /// <summary>
    /// Legt die Kopie ab. Wirft nie -- ein Misserfolg ist <b>kein</b> Fehler
    /// des Versands: Die Mail ist beim Empfaenger. Er kommt als
    /// <c>false</c> zurueck, damit die Oberflaeche einen Hinweis zeigen kann.
    /// </summary>
    Task<bool> LegeAbAsync(MimeMessage nachricht, SmtpZugang zugang, CancellationToken cancellationToken);
}
