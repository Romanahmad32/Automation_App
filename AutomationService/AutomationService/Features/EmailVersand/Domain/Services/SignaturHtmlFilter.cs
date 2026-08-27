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
/// </summary>
public static partial class SignaturHtmlFilter
{
    public static string Ohne(string html, IReadOnlySet<string> dateinamen)
    {
        if (dateinamen.Count == 0 || html.Length == 0)
        {
            return html;
        }

        return BildMarke().Replace(html, treffer =>
        {
            var quelle = QuelleMuster().Match(treffer.Value);
            var name = quelle.Success ? quelle.Groups["url"].Value : string.Empty;
            return dateinamen.Contains(name) ? string.Empty : treffer.Value;
        });
    }

    /// <summary>Die Dateinamen, auf die die Signatur noch verweist.</summary>
    public static IReadOnlyList<string> Verwendete(string html, IEnumerable<SignaturBild> bilder)
    {
        var vorhanden = html.Length == 0
            ? []
            : QuelleMuster().Matches(html).Select(treffer => treffer.Groups["url"].Value).ToHashSet(
                StringComparer.OrdinalIgnoreCase);

        return [.. bilder.Select(bild => bild.Dateiname).Where(vorhanden.Contains)];
    }

    [GeneratedRegex(@"<img\b[^>]*>", RegexOptions.IgnoreCase)]
    private static partial Regex BildMarke();

    [GeneratedRegex(@"\bsrc\s*=\s*(?<q>[""'])(?<url>[^""']*)\k<q>", RegexOptions.IgnoreCase)]
    private static partial Regex QuelleMuster();
}
