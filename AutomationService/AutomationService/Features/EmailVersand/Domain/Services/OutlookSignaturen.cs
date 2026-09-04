namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Liest die Signaturen, die im Outlook dieses Rechners eingerichtet sind
/// (§4.7 „Signatur").
///
/// Outlook legt jede Signatur dreifach ab — <c>.htm</c>, <c>.rtf</c> und
/// <c>.txt</c>. Gelesen werden zwei davon: die <b>Textfassung</b> als Outlooks
/// eigene Nur-Text-Übersetzung (Vorschau und Alternativteil der Mail) und die
/// <b>HTML-Fassung</b> samt ihren Bildern (<see cref="OutlookSignaturHtml"/>).
/// Schrift, Farben und Logo gingen sonst verloren — und genau daran erkennt
/// der Empfänger die Kanzlei. Das <c>.rtf</c> bleibt liegen: Es kann nichts,
/// was das HTML nicht kann.
///
/// Übernommen wird einmalig in die Einstellungen. Danach hängt der Versand
/// nicht mehr an Outlook.
/// </summary>
public static class OutlookSignaturen
{
    /// <summary>
    /// Eine sehr große Datei ist keine Signatur mehr, sondern ein Versehen —
    /// und gehört nicht ungeprüft unter jede Mail der Kanzlei.
    /// </summary>
    private const int MaxZeichen = 8_000;

    /// <summary>
    /// Die gefundenen Signaturen, nach Namen sortiert. Leer, wenn Outlook hier
    /// nicht eingerichtet ist — kein Fehler: Der Anwalt schreibt die Signatur
    /// dann eben selbst in die Einstellungen.
    /// </summary>
    public static IReadOnlyList<OutlookSignatur> Lies()
    {
        var ordner = Ordner();
        if (ordner is null || !Directory.Exists(ordner))
        {
            return [];
        }

        var gefunden = new List<OutlookSignatur>();
        foreach (var pfad in Directory.EnumerateFiles(ordner, "*.txt"))
        {
            var text = LiesText(pfad);
            if (text is not null)
            {
                var name = Path.GetFileNameWithoutExtension(pfad);
                gefunden.Add(new OutlookSignatur(name, text, File.Exists(HtmlPfad(ordner, name))));
            }
        }

        return [.. gefunden.OrderBy(signatur => signatur.Name, StringComparer.CurrentCultureIgnoreCase)];
    }

    /// <summary>
    /// Die formatierte Fassung dieser Signatur und ihre Bilder — für die
    /// Übernahme. Null, wenn es keine gibt oder sie unbrauchbar ist; dann
    /// bleibt es bei der Textfassung.
    /// </summary>
    public static OutlookSignaturFormat? LiesFormat(string name)
    {
        var ordner = Ordner();
        return ordner is null ? null : OutlookSignaturHtml.Lies(HtmlPfad(ordner, name));
    }

    /// <summary>
    /// Ein einzelnes Bild dieser Signatur, direkt aus Outlooks Beiordner
    /// (§4.7, ergänzt am 04.09.2026) — für die Vorschau <b>vor</b> dem
    /// Speichern.
    ///
    /// Bis dahin gab es diesen Weg nicht: Die Vorschau zeigte das neue HTML,
    /// holte die Bilder dazu aber aus der Ablage — und dort lag noch die
    /// vorige Signatur. Weil Outlook das erste Bild jeder Signatur
    /// <c>image001.png</c> nennt, traf sie dort das alte Logo und zeigte es
    /// als das neue. Wer seine Signatur wechselte, sah in der Vorschau
    /// unverändert die alte und hatte keinen Anlass, daran zu zweifeln.
    ///
    /// <paramref name="dateiname"/> ist der blanke Name aus dem gekürzten
    /// HTML; welche Datei in welchem Beiordner damit gemeint ist, weiß nur
    /// <see cref="OutlookSignaturHtml"/> — deshalb wird über dessen Auslese
    /// gesucht und nicht über einen zusammengesetzten Pfad. Ein Verweis wie
    /// <c>..\..\automation.db</c> findet so von vornherein nichts, und die
    /// Größengrenze gilt mit.
    /// </summary>
    /// <returns>Null, wenn es die Signatur, ihre formatierte Fassung oder
    /// dieses Bild darin nicht gibt.</returns>
    public static byte[]? LiesBild(string name, string dateiname)
    {
        var ordner = Ordner();
        return ordner is null
            ? null
            : OutlookSignaturHtml.Bild(HtmlPfad(ordner, name), dateiname);
    }

    /// <summary>Die Textfassung einer bestimmten Signatur, oder null.</summary>
    public static string? LiesTextVon(string name)
    {
        var ordner = Ordner();
        var blank = Path.GetFileName(name.Trim());
        return ordner is null || blank.Length == 0
            ? null
            : LiesText(Path.Combine(ordner, blank + ".txt"));
    }

    private static string HtmlPfad(string ordner, string name) =>
        Path.Combine(ordner, Path.GetFileName(name.Trim()) + ".htm");

    private static string? Ordner()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return string.IsNullOrEmpty(appData)
            ? null
            : Path.Combine(appData, "Microsoft", "Signatures");
    }

    private static string? LiesText(string pfad)
    {
        try
        {
            var datei = new FileInfo(pfad);
            if (datei.Length > MaxZeichen * 4L)
            {
                return null;
            }

            var text = TextKodierung.AlsText(File.ReadAllBytes(pfad)).Trim();
            return text.Length is 0 or > MaxZeichen ? null : text;
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }
}
