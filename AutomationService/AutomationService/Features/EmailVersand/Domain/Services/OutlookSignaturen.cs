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
