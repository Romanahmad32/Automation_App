namespace AutomationService.Features.Versicherer.Domain.Persistence;

/// <summary>
/// Persistenz-Abbild eines aus Zentralruf-Antworten gelernten Versicherers
/// (Wissensbasis, Verbesserungsplan Punkt 4). Wird automatisch aus jeder
/// geparsten Antwort befüllt/aktualisiert und dient der Oberfläche als
/// Nachschlagewerk: Lücken in neuen Antworten füllen und bei Negativ-Antworten
/// den Versicherer aus der bekannten Liste wählen. Zugleich Vorarbeit für die
/// Empfängerlogik beim E-Mail-Versand (Req. §9).
/// </summary>
public class VersichererEntity
{
    public int Id { get; set; }

    /// <summary>Name wie in der Antwort (Anzeige-Schreibweise).</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Normalisierter Name (getrimmt, Großschreibung, Whitespace kollabiert) —
    /// fachlicher Schlüssel fürs Dedupe (Unique-Index), damit Schreibvarianten
    /// derselben Gesellschaft nicht mehrere Einträge erzeugen.
    /// </summary>
    public string NameNormalisiert { get; set; } = string.Empty;

    public string? Strasse { get; set; }
    public string? Plz { get; set; }
    public string? Ort { get; set; }
    public string? Telefon { get; set; }
    public string? Fax { get; set; }
    public string? Email { get; set; }

    public DateTime ZuletztAktualisiertAm { get; set; }

    /// <summary>Herkunftshinweis, z. B. "Zentralruf-Antwort vom 12.06.2026".</summary>
    public string? Quelle { get; set; }
}
