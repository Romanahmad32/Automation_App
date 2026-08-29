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
///
/// <b>Ein Bild muss keine Marke haben.</b> Als <c>background</c> hängt es an
/// einer Tabellenzelle. Die Zelle mitsamt ihrem Inhalt zu entfernen, hiesse die
/// Signatur auseinanderzunehmen — dort fällt deshalb nur das Attribut, und die
/// Zelle bleibt ohne ihr Bild stehen.
/// </summary>
public static partial class SignaturHtmlFilter
{
    public static string Ohne(string html, IReadOnlySet<string> dateinamen)
    {
        if (dateinamen.Count == 0 || html.Length == 0)
        {
            return html;
        }

        var uebrig = BildMarken().Replace(html, treffer =>
            Zeigt(treffer.Value, dateinamen) ? string.Empty : treffer.Value);

        return HintergrundMuster().Replace(uebrig, treffer =>
            dateinamen.Contains(treffer.Groups["url"].Value) ? string.Empty : treffer.Value);
    }

    /// <summary>Die Dateinamen, auf die die Signatur noch verweist.</summary>
    public static IReadOnlyList<string> Verwendete(string html, IEnumerable<SignaturBild> bilder)
    {
        var vorhanden = html.Length == 0
            ? []
            : BildVerweis.Alle(html).ToHashSet(StringComparer.OrdinalIgnoreCase);

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
        .. BildVerweis.Alle(html)
            .Where(BildVerweis.Oertlich)
            .Distinct(StringComparer.OrdinalIgnoreCase),
    ];

    /// <summary>
    /// Ob diese Marke eines der weggelassenen Bilder zeigt. Gelesen werden alle
    /// Verweise darin: Eine VML-Form trägt ihren im eingeschlossenen
    /// <c>&lt;v:imagedata&gt;</c>, nicht an sich selbst.
    /// </summary>
    private static bool Zeigt(string marke, IReadOnlySet<string> dateinamen) =>
        BildVerweis.Alle(marke).Any(dateinamen.Contains);

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
    /// Das ganze <c>background</c>-Attribut samt führendem Leerraum. Es hängt
    /// an einer Zelle, die stehen bleiben muss — anders als bei einer Bildmarke
    /// wird deshalb nur das Attribut entfernt. Bliebe es stehen, fände
    /// <see cref="Verwendete"/> das abgewählte Bild wieder und
    /// <see cref="MailRumpf"/> bettete es erneut ein.
    /// </summary>
    [GeneratedRegex(@"\s*\bbackground\s*=\s*(?<q>[""'])(?<url>[^""']*)\k<q>",
        RegexOptions.IgnoreCase)]
    private static partial Regex HintergrundMuster();
}
