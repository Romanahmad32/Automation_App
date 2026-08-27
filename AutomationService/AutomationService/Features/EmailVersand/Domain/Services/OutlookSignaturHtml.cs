using System.Text.RegularExpressions;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Liest die formatierte Fassung einer Outlook-Signatur (§4.7): die
/// <c>.htm</c>-Datei und die Bilder, die daneben in ihrem Beiordner liegen.
///
/// Outlook legt zu jeder Signatur ein vollständiges HTML-Dokument ab und
/// daneben einen Ordner (<c>Name-Dateien</c>, in englischen Fassungen
/// <c>Name_files</c>) mit Logo, Siegel und dergleichen. Die Bildverweise darin
/// sind relativ. Für eine Mail taugen sie nicht — dort muss jedes Bild
/// mitgeschickt und über eine Content-Id angesprochen werden.
///
/// Deshalb passieren hier drei Dinge: den Rumpf aus dem Dokument schneiden
/// (Kopf, Stile und Word-Ballast bleiben draußen), die Bilder einlesen, und
/// ihre Verweise auf den blanken Dateinamen kürzen. Aus dem wird beim Versand
/// die Content-Id (<see cref="MailRumpf"/>).
/// </summary>
public static partial class OutlookSignaturHtml
{
    /// <summary>
    /// Eine Signatur, die größer ist, ist keine mehr. Outlooks HTML ist
    /// geschwätzig (Word-Stile, bedingte Kommentare), 400 KB deckt auch eine
    /// üppige Kanzleisignatur ab.
    /// </summary>
    private const int MaxZeichen = 400_000;

    /// <summary>
    /// Die formatierte Fassung, oder null, wenn es keine brauchbare gibt.
    /// Kein Fehler: Dann geht die Mail wie bisher als reiner Text hinaus.
    /// </summary>
    public static (string Html, Dictionary<string, byte[]> Bilder)? Lies(string htmPfad)
    {
        try
        {
            var datei = new FileInfo(htmPfad);
            if (!datei.Exists || datei.Length > MaxZeichen * 4L)
            {
                return null;
            }

            var dokument = TextKodierung.AlsText(File.ReadAllBytes(htmPfad));
            var rumpf = Rumpf(dokument);
            if (rumpf.Length is 0 or > MaxZeichen)
            {
                return null;
            }

            var bilder = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
            var html = BilderEinsammeln(rumpf, datei.DirectoryName ?? string.Empty, bilder);
            return (html, bilder);
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>
    /// Der Inhalt zwischen den Body-Marken. Outlooks Kopfbereich trägt eine
    /// komplette Word-Stilvorlage; sie in jede Mail zu kopieren, würde deren
    /// Text mitformatieren — die Signatur soll unter der Mail stehen, nicht
    /// bestimmen, wie die Mail aussieht.
    /// </summary>
    private static string Rumpf(string dokument)
    {
        var treffer = RumpfMuster().Match(dokument);
        return (treffer.Success ? treffer.Groups["inhalt"].Value : dokument).Trim();
    }

    /// <summary>
    /// Ersetzt jeden relativen Bildverweis durch den blanken Dateinamen und
    /// legt das Bild in <paramref name="bilder"/>. Verweise ins Netz bleiben
    /// stehen, wie sie sind: Sie zeigen auf einen Server, der sie ausliefert,
    /// und gehören nicht in die Nachricht.
    /// </summary>
    private static string BilderEinsammeln(
        string html,
        string ordner,
        Dictionary<string, byte[]> bilder)
    {
        return QuelleMuster().Replace(html, treffer =>
        {
            var verweis = treffer.Groups["url"].Value;
            var name = DateiHinter(verweis, ordner, bilder);
            return name is null
                ? treffer.Value
                : $"{treffer.Groups["vor"].Value}{name}{treffer.Groups["nach"].Value}";
        });
    }

    private static string? DateiHinter(
        string verweis,
        string ordner,
        Dictionary<string, byte[]> bilder)
    {
        if (verweis.Contains("://", StringComparison.Ordinal)
            || verweis.StartsWith("cid:", StringComparison.OrdinalIgnoreCase)
            || verweis.StartsWith("data:", StringComparison.OrdinalIgnoreCase)
            || ordner.Length == 0)
        {
            return null;
        }

        try
        {
            // Outlook schreibt Ordnernamen mit Umlauten prozentkodiert.
            var pfad = Path.GetFullPath(Path.Combine(ordner, Uri.UnescapeDataString(verweis)));
            var datei = new FileInfo(pfad);
            if (!datei.Exists || datei.Length == 0 || datei.Length > SignaturAblage.MaxBildBytes)
            {
                return null;
            }

            var name = datei.Name;
            if (!bilder.ContainsKey(name))
            {
                bilder[name] = File.ReadAllBytes(pfad);
            }

            return name;
        }
        catch (Exception ausnahme)
            when (ausnahme is IOException or UnauthorizedAccessException
                or ArgumentException or NotSupportedException or PathTooLongException)
        {
            return null;
        }
    }

    [GeneratedRegex(@"<body[^>]*>(?<inhalt>.*)</body>",
        RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex RumpfMuster();

    [GeneratedRegex(@"(?<vor>\b(?:src|background)\s*=\s*(?<q>[""']))(?<url>[^""']+)(?<nach>\k<q>)",
        RegexOptions.IgnoreCase)]
    private static partial Regex QuelleMuster();
}
