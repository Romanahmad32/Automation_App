using System.Text.Json;

namespace AutomationService.Features.RegisterHistorie.Domain.Persistence;

/// <summary>
/// Liest und schreibt die beiden JSON-Spalten des
/// <see cref="RegisterHistorieEntity"/> (Hinweise des Erzeugers, Befunde der
/// App).
///
/// Liegt in der Domain, weil sie zur Form der Entität gehört und nicht zum
/// HTTP-Vertrag: Import, Ansicht und DTO greifen alle darauf zu. Eine kaputte
/// Spalte wird zur leeren Liste und nirgends zur Ausnahme — ein Registerauszug,
/// der wegen eines unlesbaren Feldes gar nicht entsteht, wäre die schlechtere
/// Antwort als einer ohne die Hinweise zu einer Zeile.
///
/// Jeder Slice führt seinen eigenen Leser für seine JSON-Spalten (vgl.
/// <c>MandantListen</c>, <c>VersandProtokoll</c>): Die Alternative wäre eine
/// Kante zu einem fremden Slice für fünfzehn Zeilen — und die Registerhistorie
/// soll nur den Sachgebietskatalog kennen.
/// </summary>
public static class RegisterHistorieListen
{
    public static List<string> Lies(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return [];
        try
        {
            return JsonSerializer.Deserialize<List<string>>(json) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    public static string Schreib(IEnumerable<string> werte) => JsonSerializer.Serialize(werte);
}
