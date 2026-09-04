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
    public static OutlookSignaturFormat? Lies(string htmPfad)
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
            var uebergangen = new List<string>();
            var html = BilderEinsammeln(
                rumpf,
                datei.DirectoryName ?? string.Empty,
                bilder,
                uebergangen);

            // Was nicht mitkommt, darf auch nicht mehr erwähnt werden: Ein
            // Verweis auf eine Datei, die nirgends mitgeht, ist beim Empfänger
            // ein Platzhalterkreuz.
            if (uebergangen.Count > 0)
            {
                html = SignaturHtmlFilter.Ohne(
                    html,
                    uebergangen.ToHashSet(StringComparer.OrdinalIgnoreCase));
            }

            return new OutlookSignaturFormat(html, bilder, uebergangen);
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>
    /// Ein einzelnes Bild aus dem Beiordner dieser Signatur, über seinen
    /// blanken Dateinamen (§4.7) — für die Vorschau, die eine gelesene, noch
    /// nicht übernommene Signatur zeigt.
    ///
    /// Gesucht wird über <see cref="Lies"/> und nicht über einen aus dem Namen
    /// zusammengesetzten Pfad: Wie der Beiordner heißt, weiß nur das Dokument
    /// (<c>Name-Dateien</c>, englisch <c>Name_files</c>), und was darin ein
    /// Signaturbild ist, entscheidet dieselbe Auslese wie beim Übernehmen —
    /// Größengrenze eingeschlossen. Ein Verweis, der aus dem Ordner hinausführt,
    /// findet so von vornherein nichts: Verglichen wird gegen die Namen, die
    /// beim Einsammeln entstanden sind, nicht gegen das Dateisystem.
    /// </summary>
    /// <returns>Null, wenn es die Signatur, ihre formatierte Fassung oder
    /// dieses Bild darin nicht gibt.</returns>
    public static byte[]? Bild(string htmPfad, string dateiname)
    {
        var blank = Path.GetFileName(dateiname.Trim());
        return blank.Length == 0 ? null : Lies(htmPfad)?.Bilder.GetValueOrDefault(blank);
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
    ///
    /// Was gemeint war, aber nicht zu holen ist, kommt nach
    /// <paramref name="uebergangen"/> — der Aufrufer entfernt dessen
    /// Bildmarken danach.
    /// </summary>
    private static string BilderEinsammeln(
        string html,
        string ordner,
        Dictionary<string, byte[]> bilder,
        List<string> uebergangen)
    {
        return BildVerweis.Ersetze(html, verweis =>
        {
            var (name, unbrauchbar) = DateiHinter(verweis, ordner, bilder);
            if (unbrauchbar)
            {
                uebergangen.Add(verweis);
            }

            return name;
        });
    }

    /// <returns>
    /// Den blanken Dateinamen, wenn das Bild eingesammelt wurde.
    /// <c>Unbrauchbar = false</c> ohne Namen heißt „nicht unsere Sache" — ein
    /// leerer Verweis, einer ins Netz, eine Content-Id, ein eingebettetes
    /// <c>data:</c>-Bild; der bleibt unangetastet. <c>Unbrauchbar = true</c>
    /// heißt: Gemeint war
    /// eine Datei neben der Signatur, wir bekommen sie aber nicht — zu groß,
    /// leer, weg oder nicht lesbar. Dann muss die ganze Bildmarke fallen.
    /// </returns>
    private static (string? Name, bool Unbrauchbar) DateiHinter(
        string verweis,
        string ordner,
        Dictionary<string, byte[]> bilder)
    {
        if (!BildVerweis.Oertlich(verweis) || ordner.Length == 0)
        {
            return (null, false);
        }

        try
        {
            // Outlook schreibt Ordnernamen mit Umlauten prozentkodiert.
            var pfad = Path.GetFullPath(Path.Combine(ordner, Uri.UnescapeDataString(verweis)));
            var datei = new FileInfo(pfad);
            if (!datei.Exists || datei.Length == 0 || datei.Length > SignaturAblage.MaxBildBytes)
            {
                return (null, true);
            }

            var name = datei.Name;
            if (!bilder.ContainsKey(name))
            {
                bilder[name] = File.ReadAllBytes(pfad);
            }

            return (name, false);
        }
        catch (Exception ausnahme)
            when (ausnahme is IOException or UnauthorizedAccessException
                or ArgumentException or NotSupportedException or PathTooLongException)
        {
            return (null, true);
        }
    }

    [GeneratedRegex(@"<body[^>]*>(?<inhalt>.*)</body>",
        RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex RumpfMuster();
}
