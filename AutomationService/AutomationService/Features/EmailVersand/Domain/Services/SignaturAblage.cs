using AutomationService.Core.Persistence;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Verwahrt die Bilder der übernommenen Signatur unter
/// <c>%APPDATA%\AutomationService\Signatur</c> (§4.7).
///
/// Warum als Dateien und nicht in der Datenbank: Sie gehen als eingebettete
/// Ressourcen mit der Mail hinaus, MimeKit liest sie dafür vom Pfad — und die
/// Sicherung nimmt den Ordner ohnehin mit. Ein Logo in einer Textspalte wäre
/// eine base64-Kette, die jede Abfrage der Einstellungen mitschleppt.
///
/// Es gibt immer nur **eine** Signatur: <see cref="Ersetze"/> leert den Ordner,
/// bevor es füllt. Sonst blieben die Bilder jeder je übernommenen Fassung
/// liegen, und niemand wüsste, welche noch gebraucht werden.
/// </summary>
public sealed class SignaturAblage(ILogger<SignaturAblage> logger)
{
    /// <summary>
    /// Ein Bild, das größer ist als das, ist kein Signaturbild mehr, sondern
    /// ein Versehen — und ginge unter jede Mail der Kanzlei.
    ///
    /// 25 MB, damit das animierte Werbebild der Kanzlei sicher darunter liegt;
    /// als Mail werden daraus base64-kodiert rund 33 MB, also noch innerhalb
    /// des Gesamtbudgets (<see cref="EmailVersandOptions.MaxAnhangGesamtMb"/>).
    /// Wer sie erhöht, sollte beides zusammen betrachten: Ein Signaturbild, das
    /// allein die Nachrichtengrenze reißt, macht jede Mail unversendbar.
    /// </summary>
    public const long MaxBildBytes = 25L * 1024 * 1024;

    public static string Ordner()
    {
        var ordner = Path.Combine(AppDataPaths.EnsureAppDataDirectory(), "Signatur");
        Directory.CreateDirectory(ordner);
        return ordner;
    }

    /// <summary>
    /// Wirft die bisherigen Bilder weg und legt die neuen ab. Dateinamen kommen
    /// aus der Signaturdatei und werden auf den blanken Namen gekürzt: Ein
    /// Verweis wie <c>..\..\automation.db</c> wäre sonst ein Schreibzugriff
    /// dorthin.
    /// </summary>
    public IReadOnlyList<SignaturBild> Ersetze(IReadOnlyDictionary<string, byte[]> bilder)
    {
        Leere();

        var ordner = Ordner();
        var abgelegt = new List<SignaturBild>();
        foreach (var (sicher, inhalt) in Brauchbare(bilder))
        {
            try
            {
                File.WriteAllBytes(Path.Combine(ordner, sicher), inhalt);
                abgelegt.Add(new SignaturBild(sicher, inhalt.Length, SignaturMarke.Von(inhalt)));
            }
            catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
            {
                logger.LogWarning(ausnahme, "Signaturbild {Name} konnte nicht abgelegt werden.", sicher);
            }
        }

        return abgelegt;
    }

    /// <summary>
    /// Welche Bilder eine Übernahme ablegen <b>würde</b> — dieselbe Auswahl wie
    /// <see cref="Ersetze"/>, nur ohne zu schreiben.
    ///
    /// Für die Vorschau vor dem Speichern (§4.7): Sie soll aufzählen, was
    /// hinterher wirklich dasteht, und nicht ein Bild versprechen, das die
    /// Übernahme dann übergeht. Deshalb entscheidet <see cref="Brauchbare"/>
    /// für beide — zwei Filter nebeneinander liefen auseinander.
    /// </summary>
    public IReadOnlyList<SignaturBild> Vorschau(IReadOnlyDictionary<string, byte[]> bilder) =>
        [.. Brauchbare(bilder).Select(paar =>
            new SignaturBild(paar.Name, paar.Inhalt.Length, SignaturMarke.Von(paar.Inhalt)))];

    /// <summary>
    /// Die Bilder, die abgelegt werden dürfen, mit ihrem auf den blanken Namen
    /// gekürzten Dateinamen. Leere und übergroße fallen heraus.
    /// </summary>
    private static IEnumerable<(string Name, byte[] Inhalt)> Brauchbare(
        IReadOnlyDictionary<string, byte[]> bilder)
    {
        foreach (var (name, inhalt) in bilder)
        {
            var sicher = SichererName(name);
            if (sicher is null || inhalt.Length == 0 || inhalt.Length > MaxBildBytes)
            {
                continue;
            }

            yield return (sicher, inhalt);
        }
    }

    /// <summary>Was gerade abgelegt ist, nach Namen sortiert.</summary>
    public IReadOnlyList<SignaturBild> Bilder()
    {
        var ordner = Ordner();
        if (!Directory.Exists(ordner))
        {
            return [];
        }

        try
        {
            return
            [
                .. Directory.EnumerateFiles(ordner)
                    .Select(pfad => new FileInfo(pfad))
                    .Select(datei =>
                        new SignaturBild(datei.Name, datei.Length, SignaturMarke.Von(datei)))
                    .OrderBy(bild => bild.Dateiname, StringComparer.CurrentCultureIgnoreCase),
            ];
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(ausnahme, "Signaturbilder konnten nicht gelesen werden.");
            return [];
        }
    }

    /// <summary>
    /// Der Pfad zu einem abgelegten Bild, oder null. Der Name kommt aus der
    /// gespeicherten HTML-Fassung und damit mittelbar von außen — geprüft wird
    /// deshalb, dass wirklich eine Datei genau in diesem Ordner gemeint ist.
    /// </summary>
    public string? PfadVon(string dateiname)
    {
        var sicher = SichererName(dateiname);
        if (sicher is null)
        {
            return null;
        }

        var pfad = Path.Combine(Ordner(), sicher);
        return File.Exists(pfad) ? pfad : null;
    }

    /// <summary>
    /// Die Inhaltsart, unter der ein Signaturbild ausgeliefert wird. Outlook
    /// legt in seinem Beiordner nur diese Formate ab; alles andere geht als
    /// unbestimmter Bytestrom hinaus, statt als etwas ausgegeben zu werden,
    /// das es nicht ist.
    /// </summary>
    public static string InhaltsArt(string dateiname) =>
        Path.GetExtension(dateiname).ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".jpg" or ".jpeg" => "image/jpeg",
            ".gif" => "image/gif",
            ".bmp" => "image/bmp",
            ".webp" => "image/webp",
            _ => "application/octet-stream",
        };

    public void Leere()
    {
        var ordner = Ordner();
        if (!Directory.Exists(ordner))
        {
            return;
        }

        foreach (var pfad in Directory.EnumerateFiles(ordner))
        {
            try
            {
                File.Delete(pfad);
            }
            catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
            {
                logger.LogWarning(ausnahme, "Altes Signaturbild {Pfad} blieb liegen.", pfad);
            }
        }
    }

    private static string? SichererName(string name)
    {
        var blank = Path.GetFileName(name.Trim());
        if (string.IsNullOrWhiteSpace(blank) || blank is "." or "..")
        {
            return null;
        }

        return blank.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ? null : blank;
    }
}
