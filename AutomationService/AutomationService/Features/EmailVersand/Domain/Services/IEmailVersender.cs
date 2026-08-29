namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Versendet eine fertig verfasste Mail über das Postfach der Kanzlei
/// (REQUIREMENTS.md §4.7).
/// </summary>
public interface IEmailVersender
{
    /// <summary>
    /// Kann überhaupt gesendet werden? Ohne Verbindungsaufbau — die Auskunft
    /// stützt sich auf den hinterlegten Zugang und den Tokenstand.
    /// </summary>
    Task<EmailVersandBereitschaft> PruefeBereitschaftAsync(CancellationToken cancellationToken);

    /// <summary>
    /// Sendet die Nachricht. Wirft <see cref="EmailVersandException"/>, wenn
    /// nichts hinausgegangen ist — einen Teilerfolg gibt es nicht.
    /// </summary>
    Task<EmailVersandErgebnis> SendeAsync(EmailNachricht nachricht, CancellationToken cancellationToken);
}
