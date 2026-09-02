namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Ein persönlicher Zusatzgruß als **Textbaustein** (§4.7, §7.1) — einer der
/// Grüße, aus denen der Anwalt beim Verfassen wählt.
///
/// Bewusst eine Liste von Bausteinen und **kein Merkmal von Personen**: Sie
/// hängt an keinem Mandanten, ordnet niemanden ein und ist damit kein
/// besonderes personenbezogenes Datum (Art. 9 DSGVO). Was am Mandanten steht,
/// ist weiterhin freier Text (<c>MandantEntity.PersoenlicheGrussformel</c>)
/// und dient nur der Vorbelegung.
/// </summary>
public class GrussformelEntity
{
    public int Id { get; set; }

    /// <summary>
    /// Der Gruß, wie er in der Mail steht — zugleich der fachliche Schlüssel.
    /// Zweimal derselbe wäre in der Auswahl nicht auseinanderzuhalten.
    /// </summary>
    public string Text { get; set; } = string.Empty;

    /// <summary>
    /// Reihenfolge in der Auswahl. Zehnerschritte, damit sich später etwas
    /// dazwischen einsortieren lässt, ohne die ganze Liste umzunummerieren.
    /// </summary>
    public int Sortierung { get; set; }
}
