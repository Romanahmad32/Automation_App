namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Schreibt das Sachgebiete-Register als Word- und PDF-Datei in den
/// eingestellten Ablageordner (§6.2, #40).
///
/// „Spiegel" ist wörtlich zu nehmen: Die App bleibt die führende Quelle,
/// geschrieben wird nur in ihr. Die Datei im Ablageordner ist zum Lesen da —
/// unterwegs, auf dem Handy, im Ausdruck. Liegt der Ordner im synchronisierten
/// Bereich, besorgt den Rest der Synchronisierungsdienst; die App selbst kennt
/// keine Cloud.
/// </summary>
public interface IRegisterSpiegelService
{
    /// <summary>
    /// Schreibt den Spiegel, wenn ein Ablageordner eingestellt ist und sich
    /// seit dem letzten Mal etwas geändert hat.
    ///
    /// Wirft nicht: Ein gesperrtes Ziel oder ein fehlendes Word sind Lagen, die
    /// die Oberfläche erklärt, keine Programmfehler — und vor allem darf
    /// nichts davon den Vorgangsabschluss mitreißen, nach dem diese Methode
    /// läuft. Was passiert ist, steht im Ergebnis.
    /// </summary>
    /// <param name="erzwingen">
    /// Auch schreiben, wenn der Bestand unverändert ist — der Weg für den
    /// Knopf „Jetzt neu schreiben", mit dem sich eine von Hand gelöschte oder
    /// verschobene Datei zurückholen lässt.
    /// </param>
    /// <param name="cancellationToken">Bricht die PDF-Erzeugung ab.</param>
    Task<RegisterSpiegelErgebnis> SchreibeAsync(
        bool erzwingen = false,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Was der letzte Lauf hinterlassen hat, ohne selbst zu schreiben — für die
    /// Anzeige auf der Registerseite.
    /// </summary>
    Task<RegisterSpiegelErgebnis> StandAsync(CancellationToken cancellationToken = default);
}
