using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Prüfsummen, Formatversion und Grenzen gelten vor jedem schreibenden Importschritt.</summary>
public static class ArchivPruefung
{
    public const string Manifest = "sicherung-manifest.json";
    const long MaxEntpackt = 4L * 1024 * 1024 * 1024;

    public static void EntpackeGeprueft(string pfad, string ziel)
    {
        using var archiv = ZipFile.OpenRead(pfad);
        if (archiv.Entries.Count > 50000 || archiv.Entries.Sum(e => e.Length) > MaxEntpackt)
            throw new InvalidBackupException("Die Sicherung überschreitet die zulässige Größe.");
        var namen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var eintrag in archiv.Entries)
        {
            var name = eintrag.FullName;
            if (name.Contains('\\') || name.Contains(':') || name.StartsWith('/')
                || name.Split('/').Any(teil => teil is ".." or ".") || !namen.Add(name))
            {
                throw new InvalidBackupException("Die Sicherung enthält ungültige oder doppelte Dateipfade.");
            }
        }
        var manifestEintrag = archiv.GetEntry(Manifest);
        ArchivManifest? manifest = null;
        if (manifestEintrag is not null)
        {
            using var strom = manifestEintrag.Open();
            manifest = JsonSerializer.Deserialize<ArchivManifest>(strom);
            if (manifest is null || manifest.Version != 1 || manifest.Dateien is null)
                throw new InvalidBackupException("Diese Sicherungsfassung wird nicht unterstützt. Bitte die App aktualisieren.");
            if (manifest.Dateien.Count != archiv.Entries.Count - 1)
                throw new InvalidBackupException("Die Sicherung ist unvollständig.");
        }
        foreach (var eintrag in archiv.Entries.Where(e => e.FullName != Manifest))
        {
            if (eintrag.FullName.EndsWith('/')) continue;
            var datei = Path.Combine(ziel, eintrag.FullName.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(datei)!);
            using (var quelle = eintrag.Open())
            using (var ausgabe = File.Create(datei)) quelle.CopyTo(ausgabe);
            if (manifest is null) continue; // Vorhandene ältere ZIP-Sicherungen bleiben lesbar.
            using var pruefung = File.OpenRead(datei);
            if (!manifest.Dateien.TryGetValue(eintrag.FullName, out var erwartet)
                || !string.Equals(erwartet, Convert.ToHexString(SHA256.HashData(pruefung)), StringComparison.Ordinal))
            {
                throw new InvalidBackupException("Die Sicherung ist beschädigt oder noch nicht vollständig übertragen.");
            }
        }
    }
}

public sealed record ArchivManifest(int Version, SortedDictionary<string, string> Dateien);
