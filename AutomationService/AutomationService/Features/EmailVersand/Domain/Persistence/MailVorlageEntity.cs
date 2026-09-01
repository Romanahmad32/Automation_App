namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Eine vom Anwalt gepflegte Mail-Textvorlage (§4.7, §5.3): ein Name zum
/// Wiedererkennen, eine Betreffzeile und der Nachrichtentext, beide mit
/// <c>{{Platzhalter}}</c> in derselben Schreibweise wie in den Word-Vorlagen.
///
/// Der Text endet vor der Signatur. Die steht schon in den Einstellungen
/// (<see cref="Services.KanzleiSignatur"/>) und wird beim Versand angehängt —
/// eine Vorlage, die sie mitbrächte, ließe sie unter jeder Mail doppelt
/// erscheinen.
/// </summary>
public class MailVorlageEntity
{
    public int Id { get; set; }

    /// <summary>Fachlicher Schlüssel: Danach wählt der Anwalt beim Verfassen.</summary>
    public string Name { get; set; } = string.Empty;

    public string Betreff { get; set; } = string.Empty;

    public string Text { get; set; } = string.Empty;
}
