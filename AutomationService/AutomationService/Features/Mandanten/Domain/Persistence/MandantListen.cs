using System.Text.Json;

namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Liest und schreibt die beiden JSON-Spalten des <see cref="MandantEntity"/>
/// (Akten-Ordnernamen, Kennzeichen). Liegt in der Domain, weil sie zur Form der
/// Entität gehört und nicht zum HTTP-Vertrag: Register, Import und DTO greifen
/// alle darauf zu, und eine kaputte Spalte darf nirgends eine Ausnahme werden,
/// sondern wird zur leeren Liste.
/// </summary>
public static class MandantListen
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
