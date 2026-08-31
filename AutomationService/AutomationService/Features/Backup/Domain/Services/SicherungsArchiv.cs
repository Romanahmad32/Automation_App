using System.IO.Compression;
using AutomationService.Core.Persistence;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Aufbau einer Sicherungsdatei: ein ZIP mit der Datenbank und den Word-Vorlagen.
///
///     automation.db          — die Datenbank (per VACUUM INTO, WAL-sicher)
///     Vorlagen/**/*.docx     — die Vorlagen aus dem eingestellten Vorlagenordner,
///                              samt Unterordnern; Word-Sperrdateien (~$*.docx)
///                              bleiben draussen — in einem Ordner, in dem jemand
///                              Vorlagen bearbeitet, sind die der Normalfall
///
/// Bis dahin war die Sicherung eine blanke .db-Datei. Das war eine Luecke: die
/// Datenbank verweist mit absoluten Pfaden auf .docx-Dateien, die nicht
/// mitgesichert wurden. Eine Wiederherstellung auf einem neuen Rechner haette
/// Formularvorlagen ergeben, die auf nichts zeigen — und das faellt erst auf,
/// wenn ein Schreiben erzeugt werden soll.
///
/// Aeltere .db-Sicherungen bleiben einspielbar; siehe <see cref="IstArchiv"/>.
/// </summary>
public static class SicherungsArchiv
{
    public const string DatenbankEintrag = "automation.db";
    public const string VorlagenOrdner = "Vorlagen";

    // Lokaler Datei-Header eines ZIP: "PK\x03\x04".
    private static readonly byte[] ZipKennung = [0x50, 0x4B, 0x03, 0x04];

    /// <summary>
    /// Unterscheidet die neue Sicherung (ZIP) von einer aelteren blanken
    /// .db-Datei — an der Datei selbst, nicht an ihrer Endung: der Anwender
    /// benennt Sicherungen um.
    /// </summary>
    public static bool IstArchiv(string pfad)
    {
        using var datei = File.OpenRead(pfad);
        Span<byte> kopf = stackalloc byte[4];
        return datei.ReadAtLeast(kopf, 4, throwOnEndOfStream: false) == 4
               && kopf.SequenceEqual(ZipKennung);
    }

    public static async Task ErstelleAsync(
        string datenbankPfad,
        string vorlagenVerzeichnis,
        string zielPfad,
        CancellationToken cancellationToken = default)
    {
        var temporaereKopie = Path.Combine(
            Path.GetTempPath(), $"automation-db-{Guid.NewGuid():N}.db");

        try
        {
            await SqliteSicherung.VacuumIntoAsync(datenbankPfad, temporaereKopie, cancellationToken);

            using var archiv = ZipFile.Open(zielPfad, ZipArchiveMode.Create);
            archiv.CreateEntryFromFile(temporaereKopie, DatenbankEintrag, CompressionLevel.Optimal);

            if (!Directory.Exists(vorlagenVerzeichnis))
            {
                return;
            }

            foreach (var vorlage in Directory.EnumerateFiles(
                vorlagenVerzeichnis, "*.docx", SearchOption.AllDirectories))
            {
                if (IstSperrdatei(vorlage))
                {
                    continue;
                }

                var relativ = Path.GetRelativePath(vorlagenVerzeichnis, vorlage)
                    .Replace(Path.DirectorySeparatorChar, '/');
                archiv.CreateEntryFromFile(
                    vorlage,
                    $"{VorlagenOrdner}/{relativ}",
                    CompressionLevel.Optimal);
            }
        }
        finally
        {
            TryDelete(temporaereKopie);
        }
    }

    /// <summary>Word-Sperrdatei (~$…): entsteht, solange eine Vorlage offen ist.</summary>
    public static bool IstSperrdatei(string pfad) =>
        Path.GetFileName(pfad).StartsWith("~$", StringComparison.Ordinal);

    public static void Entpacke(string archivPfad, string zielVerzeichnis)
    {
        Directory.CreateDirectory(zielVerzeichnis);
        ZipFile.ExtractToDirectory(archivPfad, zielVerzeichnis, overwriteFiles: true);
    }

    private static void TryDelete(string pfad)
    {
        try
        {
            if (File.Exists(pfad))
            {
                File.Delete(pfad);
            }
        }
        catch (IOException)
        {
            // Temporaerdatei: wird spaetestens beim naechsten Aufraeumen ueberschrieben.
        }
    }
}
