using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Komprimiert und prüft im selben Durchlauf, mit begrenztem Speicherbedarf.</summary>
public sealed class ArchivSchreiber(ZipArchive archiv)
{
    readonly SortedDictionary<string, string> _dateien = new(StringComparer.Ordinal);

    public void Datei(string quelle, string name)
    {
        if (_dateien.ContainsKey(name)) return;
        using var eingang = File.OpenRead(quelle);
        using var ausgang = archiv.CreateEntry(name, CompressionLevel.Fastest).Open();
        using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        var puffer = new byte[81920];
        int gelesen;
        while ((gelesen = eingang.Read(puffer)) > 0)
        {
            hash.AppendData(puffer, 0, gelesen);
            ausgang.Write(puffer, 0, gelesen);
        }
        _dateien.Add(name, Convert.ToHexString(hash.GetHashAndReset()));
    }

    public void Abschliessen()
    {
        using var ziel = archiv.CreateEntry(ArchivPruefung.Manifest).Open();
        JsonSerializer.Serialize(ziel, new ArchivManifest(1, _dateien));
    }
}
