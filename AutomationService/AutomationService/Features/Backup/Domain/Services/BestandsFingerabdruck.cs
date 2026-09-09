using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Inhalt statt WAL-Zeitpunkt: Öffnen, Checkpoints und VACUUM sind keine neue Arbeit.</summary>
public sealed class BestandsFingerabdruck(string datenbank, Func<string> vorlagen)
{
    string? _merkmal;
    string? _hash;
    readonly object _schloss = new();

    public string Lies()
    {
        lock (_schloss)
        {
            var ordner = new[] { vorlagen(), Path.Combine(Path.GetDirectoryName(datenbank)!, AnhangSicherung.Ordner) };
            var dateien = ordner.SelectMany((wurzel, index) => Directory.Exists(wurzel)
                ? Directory.EnumerateFiles(wurzel, index == 0 ? "*.docx" : "*", SearchOption.AllDirectories)
                    .Where(p => !SicherungsArchiv.IstSperrdatei(p))
                    .Select(p => (Pfad: p, Name: $"{index}/{Path.GetRelativePath(wurzel, p)}"))
                : []).OrderBy(d => d.Name, StringComparer.Ordinal).ToList();
            var merkmal = AenderungsMerkmal.Fingerabdruck(datenbank) + string.Join('|', dateien.Select(d =>
                $"{d.Pfad}:{new FileInfo(d.Pfad).Length}:{File.GetLastWriteTimeUtc(d.Pfad).Ticks}"));
            if (merkmal == _merkmal && _hash is not null) return _hash;
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            using var db = new SqliteConnection($"Data Source={datenbank};Mode=ReadOnly;Pooling=False");
            db.Open();
            using var tx = db.BeginTransaction();
            var tabellen = new List<string>();
            using (var cmd = db.CreateCommand())
            {
                cmd.Transaction = tx;
                cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name";
                using var reader = cmd.ExecuteReader();
                while (reader.Read()) tabellen.Add(reader.GetString(0));
            }
            foreach (var tabelle in tabellen)
            {
                FuegeHinzu(hash, tabelle);
                using var cmd = db.CreateCommand();
                cmd.Transaction = tx;
                var name = tabelle.Replace("\"", "\"\"", StringComparison.Ordinal);
                cmd.CommandText = $"SELECT * FROM \"{name}\" ORDER BY rowid";
                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    var werte = new object[reader.FieldCount];
                    reader.GetValues(werte);
                    FuegeHinzu(hash, JsonSerializer.Serialize(werte));
                }
            }
            foreach (var datei in dateien)
            {
                FuegeHinzu(hash, datei.Name);
                using var strom = File.OpenRead(datei.Pfad);
                hash.AppendData(SHA256.HashData(strom));
            }
            _hash = Convert.ToHexString(hash.GetHashAndReset());
            _merkmal = merkmal;
            return _hash;
        }
    }

    static void FuegeHinzu(IncrementalHash hash, string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        hash.AppendData(BitConverter.GetBytes(bytes.Length));
        hash.AppendData(bytes);
    }
}
