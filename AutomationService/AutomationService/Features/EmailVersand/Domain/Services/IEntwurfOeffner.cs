namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Öffnet die fertig verfasste Mail als Entwurf im Mailprogramm, statt sie zu
/// senden (§4.7).
///
/// Der zweite Weg neben dem Direktversand, und zwar für das, was die App nicht
/// hat: eine Datei aus einer anderen Nachricht, ein Satz, der im gewohnten
/// Fenster schneller getippt ist. Zugleich die Rückfalltür, wenn der
/// Direktversand scheitert.
/// </summary>
public interface IEntwurfOeffner
{
    /// <summary>
    /// Wirft <see cref="EmailVersandException"/>, wenn sich der Entwurf
    /// nirgends öffnen ließ. Gesendet wird auf diesem Weg grundsätzlich nichts.
    /// </summary>
    Task<EntwurfErgebnis> OeffneAsync(EmailNachricht nachricht, CancellationToken cancellationToken);
}
