using System.Text;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Liest die Signaturen, die im Outlook dieses Rechners eingerichtet sind
/// (§4.7 „Signatur").
///
/// Outlook legt jede Signatur dreifach ab — <c>.htm</c>, <c>.rtf</c> und
/// <c>.txt</c> — unter <c>%APPDATA%\Microsoft\Signatures</c>. Gelesen wird die
/// <b>Textfassung</b>: Sie ist Outlooks eigene Nur-Text-Übersetzung derselben
/// Signatur, also genau das, was die Kanzlei bei Nur-Text-Mails ohnehin
/// verschickt. HTML zu konvertieren hieße nachzubauen, was hier fertig
/// daliegt — und ein Logo bekäme man dabei ohnehin nicht mit.
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
                gefunden.Add(new OutlookSignatur(Path.GetFileNameWithoutExtension(pfad), text));
            }
        }

        return [.. gefunden.OrderBy(signatur => signatur.Name, StringComparer.CurrentCultureIgnoreCase)];
    }

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

            var text = AlsText(File.ReadAllBytes(pfad)).Trim();
            return text.Length is 0 or > MaxZeichen ? null : text;
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    /// <summary>
    /// Die Kodierung steht nicht fest: Neuere Outlook-Fassungen schreiben UTF-8
    /// (meist mit BOM), ältere in der ANSI-Codepage. Blind als UTF-8 zu lesen
    /// machte aus jedem Umlaut ein Fragezeichen — bei einer Kanzleisignatur der
    /// sichtbarste denkbare Fehler.
    /// </summary>
    private static string AlsText(byte[] bytes)
    {
        if (bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
        {
            return Encoding.UTF8.GetString(bytes, 3, bytes.Length - 3);
        }

        if (bytes.Length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE)
        {
            return Encoding.Unicode.GetString(bytes, 2, bytes.Length - 2);
        }

        try
        {
            return new UTF8Encoding(false, throwOnInvalidBytes: true).GetString(bytes);
        }
        catch (DecoderFallbackException)
        {
            // Latin-1 deckt die deutschen Umlaute deckungsgleich mit
            // Windows-1252 ab und ist eingebaut — der CodePages-Provider wäre
            // eine Abhängigkeit für eine Handvoll Zeichen.
            return Encoding.Latin1.GetString(bytes);
        }
    }
}
