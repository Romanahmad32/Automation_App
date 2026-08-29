using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die Einlieferung beim Postausgangsserver -- der eine Schritt des Versands,
/// der wirklich hinausgeht (REQUIREMENTS.md §4.7).
///
/// Eigene Naht, weil alles davor und danach pruefbar sein soll, ohne dass eine
/// Mail das Haus verlaesst: Zugangspruefung, Anhangsgrenzen, Signatur,
/// Kopie in "Gesendet" und Protokolleintrag haengen an dieser einen Zeile.
/// Bis es sie gab, baute <see cref="SmtpEmailVersender"/> seinen Client selbst
/// -- und der ganze Weg liess sich nur erlesen, nicht ausfuehren.
/// </summary>
public interface ISmtpUebergabe
{
    /// <summary>
    /// Liefert ein. Wirft <see cref="EmailVersandException"/>, wenn nichts
    /// hinausgegangen ist -- einen Teilerfolg gibt es nicht.
    /// </summary>
    Task UebergebeAsync(MimeMessage mime, SmtpZugang zugang, CancellationToken cancellationToken);
}
