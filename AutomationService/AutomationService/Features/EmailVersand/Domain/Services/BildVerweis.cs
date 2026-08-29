using System.Text.RegularExpressions;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Das eine Muster für einen Bildverweis in Signatur-HTML (§4.7).
///
/// Drei Stellen brauchen es: das Übernehmen aus Outlook
/// (<see cref="OutlookSignaturHtml"/>) kürzt die Verweise auf den blanken
/// Dateinamen, das Abwählen (<see cref="SignaturHtmlFilter"/>) liest sie, und
/// das Einbetten (<see cref="MailRumpf"/>) tauscht sie gegen die Content-Id.
/// Zusammengezogen, weil sie sonst auseinanderlaufen: Wer das Muster einmal
/// erweitert — etwa um <c>srcset</c> — erweitert es sicher nicht an allen drei
/// Stellen. Dann wird ein Bild eingesammelt, das sich nicht mehr abwählen
/// lässt, oder eines abgewählt, das trotzdem mit hinausgeht.
///
/// <c>background</c> zählt mit: Outlook hängt damit Hintergrundbilder an
/// Tabellenzellen, und die gehen genauso mit hinaus wie ein <c>src</c>.
/// </summary>
internal static partial class BildVerweis
{
    /// <summary>Alle Verweise in der Reihenfolge ihres Vorkommens.</summary>
    public static IEnumerable<string> Alle(string html) =>
        Muster().Matches(html).Select(treffer => treffer.Groups["url"].Value);

    /// <summary>
    /// Ersetzt jeden Verweis durch das, was <paramref name="neu"/> dafür
    /// liefert. Null lässt ihn unangetastet stehen — samt Anführungszeichen
    /// und Attributnamen, die dabei nie angefasst werden.
    /// </summary>
    public static string Ersetze(string html, Func<string, string?> neu) =>
        Muster().Replace(html, treffer =>
        {
            var ersatz = neu(treffer.Groups["url"].Value);
            return ersatz is null
                ? treffer.Value
                : $"{treffer.Groups["vor"].Value}{ersatz}{treffer.Groups["nach"].Value}";
        });

    /// <summary>
    /// Ob dieser Verweis auf eine <b>Datei neben der Signatur</b> zeigt — also
    /// weder ins Netz noch auf eine Content-Id noch auf ein eingebettetes
    /// Bild. Nur solche Verweise brauchen eine abgelegte Datei hinter sich.
    /// </summary>
    public static bool Oertlich(string verweis) =>
        verweis.Length > 0
        && !verweis.Contains("://", StringComparison.Ordinal)
        && !verweis.StartsWith("cid:", StringComparison.OrdinalIgnoreCase)
        && !verweis.StartsWith("data:", StringComparison.OrdinalIgnoreCase);

    [GeneratedRegex(@"(?<vor>\b(?:src|background)\s*=\s*(?<q>[""']))(?<url>[^""']*)(?<nach>\k<q>)",
        RegexOptions.IgnoreCase)]
    private static partial Regex Muster();
}
