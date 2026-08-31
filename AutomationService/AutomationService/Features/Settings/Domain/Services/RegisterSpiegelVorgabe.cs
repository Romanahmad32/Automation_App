namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Vorgaben und gueltige Werte fuer den Register-Spiegel (§6.2, #40).
///
/// Liegt im Settings-Slice, weil beides Einstellungswerte sind — der Vorgaenge-
/// Slice, der den Spiegel schreibt, haengt ohnehin schon an den Einstellungen
/// (Auftragsnummer beim Abschluss). Die umgekehrte Richtung gaebe es damit
/// zweimal, und die Konstanten wuerden zwischen zwei Slices wandern.
/// </summary>
public static class RegisterSpiegelVorgabe
{
    /// <summary>
    /// Basisname der Spiegeldateien ohne Endung. Der Zusatz "(App)" ist kein
    /// Schmuck: Die Datei landet in aller Regel in demselben synchronisierten
    /// Ordner, in dem auch das gewachsene Kanzleidokument liegt, und muss auf
    /// den ersten Blick von ihm zu unterscheiden sein.
    /// </summary>
    public const string Dateiname = "Sachgebiete-Register (App)";

    /// <summary>Alle Vorgaenge kommen in die Datei — die Vorgabe.</summary>
    public const string FilterAlle = "alle";

    /// <summary>Nur abgeschlossene (versendete) Vorgaenge kommen in die Datei.</summary>
    public const string FilterAbgeschlossen = "abgeschlossen";

    /// <summary>
    /// Liest den Filter tolerant: Ein unbekannter oder leerer Wert bedeutet
    /// <see cref="FilterAlle"/>. Ein Registerauszug, der wegen eines
    /// unverstandenen Einstellungswerts stillschweigend Zeilen weglaesst, waere
    /// die schlechtere Antwort als einer, der zu viel zeigt.
    /// </summary>
    public static bool NurAbgeschlossene(string? filter) =>
        string.Equals(filter?.Trim(), FilterAbgeschlossen, StringComparison.OrdinalIgnoreCase);
}
