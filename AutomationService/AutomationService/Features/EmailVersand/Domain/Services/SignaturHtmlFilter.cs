using System.Text.RegularExpressions;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Nimmt Bilder aus der formatierten Signatur heraus, die für <b>diese</b> Mail
/// nicht mitgehen sollen (§4.7).
///
/// Der Anlass ist der Alltag der Kanzlei: In der Signatur steckt ein animiertes
/// Werbebild von mehreren Megabyte, das nicht unter jeder Nachricht stehen
/// muss. Bisher wurde es dafür in Outlook von Hand aus dem Entwurf gelöscht.
///
/// Entfernt wird die ganze Bildmarke, nicht nur ihr Verweis: Ein
/// <c>&lt;img&gt;</c> ohne Quelle zeigt beim Empfänger ein Platzhalterkreuz,
/// und das sähe nach einem Fehler aus statt nach einer Entscheidung.
///
/// <b>Ein Bild steht in Outlooks Signatur zweimal.</b> Word schreibt jedes Bild
/// als VML-Form (<c>&lt;v:shape&gt;</c> mit <c>&lt;v:imagedata&gt;</c>, in einem
/// bedingten Kommentar <c>[if gte vml 1]</c>) <em>und</em> daneben als
/// gewöhnliches <c>&lt;img&gt;</c> für alle übrigen Programme
/// (<c>[if !vml]</c>). Nur das <c>&lt;img&gt;</c> zu entfernen, hiess deshalb:
/// Outlook — das Programm, das die meisten Empfänger benutzen — zeigt das
/// abgewählte Bild weiterhin an, und es geht auch weiterhin mit hinaus. Beide
/// Fassungen müssen fallen.
/// </summary>
public static partial class SignaturHtmlFilter
{
    public static string Ohne(string html, IReadOnlySet<string> dateinamen)
    {
        if (dateinamen.Count == 0 || html.Length == 0)
        {
            return html;
        }

        return BildMarken().Replace(html, treffer =>
            Zeigt(treffer.Value, dateinamen) ? string.Empty : treffer.Value);
    }

    /// <summary>Die Dateinamen, auf die die Signatur noch verweist.</summary>
    public static IReadOnlyList<string> Verwendete(string html, IEnumerable<SignaturBild> bilder)
    {
        var vorhanden = html.Length == 0
            ? []
            : VerweisMuster().Matches(html).Select(treffer => treffer.Groups["url"].Value).ToHashSet(
                StringComparer.OrdinalIgnoreCase);

        return [.. bilder.Select(bild => bild.Dateiname).Where(vorhanden.Contains)];
    }

    /// <summary>
    /// Alle Verweise, die auf eine <b>Datei neben der Signatur</b> zeigen —
    /// also weder ins Netz noch auf eine Content-Id noch auf ein eingebettetes
    /// Bild. Genau diese muessen eine abgelegte Datei hinter sich haben; sonst
    /// steht beim Empfaenger ein Platzhalterkreuz.
    /// </summary>
    public static IReadOnlyList<string> OertlicheQuellen(string html) =>
    [
        .. VerweisMuster().Matches(html)
            .Select(treffer => treffer.Groups["url"].Value)
            .Where(Oertlich)
            .Distinct(StringComparer.OrdinalIgnoreCase),
    ];

    private static bool Oertlich(string verweis) =>
        verweis.Length > 0
        && !verweis.Contains("://", StringComparison.Ordinal)
        && !verweis.StartsWith("cid:", StringComparison.OrdinalIgnoreCase)
        && !verweis.StartsWith("data:", StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Ob diese Marke eines der weggelassenen Bilder zeigt. Gelesen werden alle
    /// Verweise darin: Eine VML-Form trägt ihren im eingeschlossenen
    /// <c>&lt;v:imagedata&gt;</c>, nicht an sich selbst.
    /// </summary>
    private static bool Zeigt(string marke, IReadOnlySet<string> dateinamen) =>
        VerweisMuster().Matches(marke).Any(treffer => dateinamen.Contains(treffer.Groups["url"].Value));

    /// <summary>
    /// Alles, was ein Bild an die Stelle setzt: die VML-Form mitsamt Inhalt,
    /// ein alleinstehendes <c>v:imagedata</c> und die gewöhnliche Bildmarke.
    /// Die <c>v:shapetype</c>-Vorlage daneben bleibt stehen — sie zeichnet
    /// nichts, solange keine Form auf sie verweist.
    /// </summary>
    [GeneratedRegex(@"<v:shape\b[^>]*>.*?</v:shape\s*>|<v:imagedata\b[^>]*>|<img\b[^>]*>",
        RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex BildMarken();

    /// <summary>
    /// Ein Bildverweis. <c>background</c> zählt mit: Outlook hängt damit
    /// Hintergrundbilder an Tabellenzellen, und die gehen genauso mit hinaus
    /// wie ein <c>src</c>.
    /// </summary>
    [GeneratedRegex(@"\b(?:src|background)\s*=\s*(?<q>[""'])(?<url>[^""']*)\k<q>",
        RegexOptions.IgnoreCase)]
    private static partial Regex VerweisMuster();
}
