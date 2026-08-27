using AutomationService.Core.Persistence;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Verwaltet die Ordner, in denen Anhänge zwischenlagern, bis sie versendet
/// sind (§4.3, §4.7) — und räumt sie wieder weg.
///
/// Sie liegen unter <c>%APPDATA%</c> und nicht unter <c>%TEMP%</c>, weil sie
/// beim Versand noch gebraucht werden, unter Umständen Tage nach dem Erfassen;
/// Windows räumt <c>%TEMP%</c> ohne Vorwarnung. Der Preis dafür ist, dass sie
/// niemand von selbst wieder wegnimmt — genau das erledigt diese Klasse, nach
/// derselben Regel wie <c>ArbeitsVerzeichnis</c> beim Arbeitsordner:
/// <see cref="MaxAlterTage"/> Tage unberührt, dann weg.
///
/// Ein Gutachten mit Lichtbildern hat zweistellige Megabyte. Über Jahre ist das
/// der Unterschied zwischen unauffällig und ärgerlich.
/// </summary>
public sealed class AnhangAblage(ILogger<AnhangAblage> logger)
{
    /// <summary>
    /// Dieselbe Grenze wie beim Arbeitsordner und beim PDF-Cache. Wer eine
    /// Antwort zwei Wochen liegen lässt, holt ihre Anhänge neu — die Nachricht
    /// liegt ja weiter im Postfach.
    /// </summary>
    private const int MaxAlterTage = 14;

    /// <summary>Was aus einer geöffneten Outlook-Nachricht geholt wurde.</summary>
    public static string OutlookOrdner()
    {
        var ordner = Path.Combine(AppDataPaths.EnsureAnhaengeDirectory(), "Outlook");
        Directory.CreateDirectory(ordner);
        return ordner;
    }

    /// <summary>
    /// Löscht eine aus Outlook geholte Datei — für den Anwalt, der einen
    /// Vorschlag verwirft.
    ///
    /// Der Pfad kommt von außen und wird deshalb gegen genau diesen einen
    /// Ordner geprüft. **Nicht** gegen die ganze Ablage: Die Anhänge erfasster
    /// Antworten liegen daneben und sollen liegen bleiben (§4.3) — sie gehören
    /// der Antwort, nicht dem einzelnen Entwurf, und werden für das nächste
    /// Schreiben noch gebraucht.
    /// </summary>
    /// <returns>True, wenn die Datei danach weg ist.</returns>
    public bool VerwirfGeholten(string pfad)
    {
        if (string.IsNullOrWhiteSpace(pfad))
        {
            return false;
        }

        try
        {
            var voll = Path.GetFullPath(pfad);
            if (!LiegtImOutlookOrdner(voll))
            {
                logger.LogWarning("Löschen abgelehnt, nicht aus Outlook geholt: {Pfad}", voll);
                return false;
            }

            if (File.Exists(voll))
            {
                File.Delete(voll);
            }

            return true;
        }
        catch (Exception ausnahme)
            when (ausnahme is IOException or UnauthorizedAccessException
                or ArgumentException or NotSupportedException or PathTooLongException)
        {
            logger.LogWarning(ausnahme, "Anhang konnte nicht gelöscht werden: {Pfad}", pfad);
            return false;
        }
    }

    /// <summary>
    /// Räumt ab, was seit <see cref="MaxAlterTage"/> Tagen niemand mehr
    /// angefasst hat: verworfene Griffe nach Outlook, Anhänge von Antworten,
    /// die nie zu einem Schreiben führten, Kopien umbenannter Anhänge.
    /// Best-Effort — ein Fehler beim Aufräumen darf den Start nicht aufhalten.
    /// </summary>
    public void AltesLoeschen()
    {
        var grenze = DateTime.UtcNow.AddDays(-MaxAlterTage);
        RaeumeAuf(AppDataPaths.EnsureAnhaengeDirectory(), grenze);

        // Die beiden Temp-Ordner raeumt Windows irgendwann selbst; ihn dabei
        // nicht warten zu lassen, kostet hier nichts.
        var temp = Path.Combine(Path.GetTempPath(), "AutomationService");
        RaeumeAuf(Path.Combine(temp, "Anhaenge"), grenze);
        RaeumeAuf(Path.Combine(temp, "Entwuerfe"), grenze);
    }

    private void RaeumeAuf(string wurzel, DateTime grenze)
    {
        try
        {
            if (!Directory.Exists(wurzel))
            {
                return;
            }

            foreach (var datei in Directory.EnumerateFiles(wurzel, "*", SearchOption.AllDirectories))
            {
                if (File.GetLastWriteTimeUtc(datei) < grenze)
                {
                    File.Delete(datei);
                }
            }

            LeereOrdnerLoeschen(wurzel);
        }
        catch (Exception ausnahme)
            when (ausnahme is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(ausnahme, "Aufräumen von {Wurzel} fehlgeschlagen (unkritisch).", wurzel);
        }
    }

    /// <summary>
    /// Was nach dem Löschen leer zurückbleibt, gehört mit weg — ein Ordner je
    /// erfasster Antwort summiert sich sonst zu tausenden leeren Hüllen.
    /// </summary>
    private static void LeereOrdnerLoeschen(string wurzel)
    {
        foreach (var ordner in Directory.EnumerateDirectories(wurzel, "*", SearchOption.AllDirectories)
            .OrderByDescending(pfad => pfad.Length))
        {
            if (!Directory.EnumerateFileSystemEntries(ordner).Any())
            {
                Directory.Delete(ordner);
            }
        }
    }

    private static bool LiegtImOutlookOrdner(string vollerPfad)
    {
        var ordner = Path.GetFullPath(OutlookOrdner());
        return vollerPfad.StartsWith(
            ordner.EndsWith(Path.DirectorySeparatorChar) ? ordner : ordner + Path.DirectorySeparatorChar,
            StringComparison.OrdinalIgnoreCase);
    }
}
