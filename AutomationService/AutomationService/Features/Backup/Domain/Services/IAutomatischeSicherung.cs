namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Legt den Stand ohne Zutun des Anwalts im eingestellten Ablageordner ab
/// (§7.2, #39) — beim Beenden der App und nach jedem Vorgangsabschluss.
/// </summary>
public interface IAutomatischeSicherung
{
    /// <summary>
    /// Schreibt eine Sicherung und schreibt die Arbeitsplatz-Akte fort.
    ///
    /// Wirft nicht: Beide Aufrufer sind Nebensachen an Stellen, an denen die
    /// Hauptsache schon feststeht (der Vorgang ist abgeschlossen, die App geht
    /// zu). Ein Fehlschlag kommt als Ergebnis zurueck und wird lokal gemerkt,
    /// damit ihn der naechste Start zeigen kann.
    /// </summary>
    /// <returns>
    /// Das Ergebnis des Laufs, oder <c>null</c>, wenn kein Ablageordner
    /// eingestellt ist — dann ist die automatische Sicherung abgeschaltet und es
    /// gab nichts zu tun.
    /// </returns>
    Task<LetzteSicherung?> SchreibeAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Traegt beim Start ein, dass an diesem Arbeitsplatz gearbeitet wird — der
    /// Zeitpunkt, den der andere Rechner spaeter als „zuletzt … gearbeitet"
    /// liest. Der gesicherte Stand bleibt dabei unberuehrt.
    ///
    /// Liegt hier und nicht beim Aufrufer, weil es denselben Ablageordner und
    /// dieselbe Akte betrifft: Wer den Ordner kennt, schreibt beides — sonst
    /// muesste die Einstellung an zwei Stellen aufgeloest werden.
    /// Wirft nicht.
    /// </summary>
    void MerkeArbeitsbeginn();
}
