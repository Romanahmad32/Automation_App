namespace AutomationService.Features.Settings.Domain.Persistence;

/// <summary>
/// Eine vom Anwalt konfigurierte Standardposition der Schadensaufstellung
/// (§4.4): Mit diesen Zeilen startet jede neu begonnene Aufstellung im
/// Word-Assistenten. Bezeichnung und optional ein vorbelegter Betrag; ohne
/// Betrag bleibt das Betragsfeld leer und die Position fällt beim Erzeugen
/// des Dokuments von selbst heraus.
///
/// Eine leere Tabelle bedeutet „nicht konfiguriert" — dann liefert das
/// Repository die fünf üblichen Positionen (<see cref="Services.StandardSchadenspositionenVorgabe"/>).
/// </summary>
public class StandardSchadenspositionEntity
{
    public int Id { get; set; }

    /// <summary>Anzeige- und Vorbelegungsreihenfolge, beginnend bei 0.</summary>
    public int Reihenfolge { get; set; }

    public string Bezeichnung { get; set; } = string.Empty;

    /// <summary>Vorbelegter Betrag in Euro; null heißt: Feld bleibt leer.</summary>
    public decimal? Betrag { get; set; }
}
