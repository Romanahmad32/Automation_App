namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Welche Ursache hinter <see cref="AktualisierungsZustand.Fehler"/> steht
/// (#196). Das Frontend nennt danach im Dialog einen kurzen Satz oder den
/// Satz des Dienstes — es soll die Ursache nicht aus dem deutschen Wortlaut
/// von <see cref="AktualisierungsFehler.Meldung"/> erraten müssen.
/// </summary>
public enum AktualisierungsFehlerArt
{
    /// <summary>
    /// Die Leitung riss ab oder stockte (<see cref="AktualisierungsMeldungen.Unterbrochen"/>,
    /// <see cref="AktualisierungsMeldungen.Stockt"/>) — „Meist fehlt nur kurz die Internetverbindung."
    /// </summary>
    Verbindung,

    /// <summary>
    /// Größe oder SHA256 stimmten nicht, oder es kam mehr an als angekündigt;
    /// die Datei ist gelöscht — „Die Datei kam nicht vollständig an und wird nicht verwendet."
    /// </summary>
    Pruefung,

    /// <summary>
    /// Alles, wofür kein kurzer Satz passt; dann gilt die Meldung selbst:
    /// Setup-Datei oder Prüfsumme fehlen bei GitHub, Festplatte voll, die
    /// geladene Datei ist verschwunden, der Start wurde verweigert.
    /// </summary>
    Sonstig,
}

/// <summary>Ein Fehler, wie der Anwender ihn sieht: Ursache und Satz.</summary>
/// <param name="Art">Für die Wahl des kurzen Satzes im Dialog.</param>
/// <param name="Meldung">Deutsch und für den Anwender — nie der Text einer Ausnahme.</param>
public sealed record AktualisierungsFehler(AktualisierungsFehlerArt Art, string Meldung)
{
    /// <summary>
    /// Zu einer gescheiterten Prüfung der Setup-Datei. <see cref="SetupPruefErgebnis.Fehlt"/>
    /// zählt nicht als <see cref="AktualisierungsFehlerArt.Pruefung"/>: Die Datei ist
    /// nicht falsch angekommen, sondern verschwunden (Virenscanner, Aufräumen) —
    /// „kam nicht vollständig an" stimmte dann nicht, der Satz des Dienstes schon.
    /// </summary>
    public static AktualisierungsFehler Zu(SetupPruefErgebnis ergebnis) => new(
        ergebnis == SetupPruefErgebnis.Fehlt ? AktualisierungsFehlerArt.Sonstig : AktualisierungsFehlerArt.Pruefung,
        AktualisierungsMeldungen.Fuer(ergebnis));
}
