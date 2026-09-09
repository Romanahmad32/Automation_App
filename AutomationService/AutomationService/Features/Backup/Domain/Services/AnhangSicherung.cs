using System.Text.Json;
using System.Globalization;
using Microsoft.Data.Sqlite;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>Mailanhänge reisen mit; in der Sicherung stehen nur Pfade relativ zu Anhaenge/.</summary>
public static class AnhangSicherung
{
    public const string Ordner = "Anhaenge";

    public static void Packe(string datenbank, string wurzel, ArchivSchreiber archiv)
    {
        using var db = new SqliteConnection($"Data Source={datenbank};Pooling=False");
        db.Open();
        foreach (var (id, pfade) in Lies(db))
        {
            var portable = new List<string>();
            foreach (var pfad in pfade)
            {
                var relativ = Relativ(pfad, wurzel);
                var quelle = Path.Combine(wurzel, relativ);
                if (!File.Exists(quelle))
                    throw new InvalidBackupException($"Ein erfasster Mailanhang fehlt: {Path.GetFileName(pfad)}. Bitte zuerst wiederherstellen.");
                var name = $"{Ordner}/{relativ.Replace('\\', '/')}";
                archiv.Datei(quelle, name);
                portable.Add(relativ.Replace('\\', '/'));
            }
            Speichere(db, id, portable);
        }
    }

    public static void PassePfadeAn(string datenbank, string wurzel, string? quelle)
    {
        using var db = new SqliteConnection($"Data Source={datenbank};Pooling=False");
        db.Open();
        foreach (var (id, pfade) in Lies(db))
        {
            var lokal = new List<string>();
            foreach (var pfad in pfade)
            {
                // Alte Sicherungen enthielten keine Anhänge; deren Pfade nicht erraten.
                if (quelle is null) { lokal.Add(pfad); continue; }
                var relativ = Relativ(pfad, wurzel);
                if (!File.Exists(Path.Combine(quelle, relativ)))
                    throw new InvalidBackupException("In der Sicherung fehlt ein erfasster Mailanhang.");
                lokal.Add(Path.Combine(wurzel, relativ));
            }
            Speichere(db, id, lokal);
        }
    }

    static List<(long Id, string[] Pfade)> Lies(SqliteConnection db)
    {
        using var schema = db.CreateCommand();
        schema.CommandText = "SELECT count(*) FROM pragma_table_info('ReceivedReplies') WHERE name='AnhaengeJson'";
        if (Convert.ToInt64(schema.ExecuteScalar(), CultureInfo.InvariantCulture) == 0) return [];
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT Id, AnhaengeJson FROM ReceivedReplies WHERE AnhaengeJson IS NOT NULL";
        using var reader = cmd.ExecuteReader();
        var result = new List<(long, string[])>();
        while (reader.Read()) result.Add((reader.GetInt64(0), JsonSerializer.Deserialize<string[]>(reader.GetString(1)) ?? []));
        return result;
    }

    static void Speichere(SqliteConnection db, long id, IReadOnlyList<string> pfade)
    {
        using var cmd = db.CreateCommand();
        cmd.CommandText = "UPDATE ReceivedReplies SET AnhaengeJson=$pfade WHERE Id=$id";
        cmd.Parameters.AddWithValue("$pfade", JsonSerializer.Serialize(pfade));
        cmd.Parameters.AddWithValue("$id", id);
        cmd.ExecuteNonQuery();
    }

    static string Relativ(string pfad, string wurzel)
    {
        var relativ = Path.IsPathRooted(pfad) ? Path.GetRelativePath(wurzel, pfad) : pfad;
        if (Path.IsPathRooted(relativ) || relativ.Contains(':')
            || relativ.Split(['/', '\\']).Any(s => s is ".." or "."))
        {
            throw new InvalidBackupException("Ein Mailanhang liegt außerhalb des vorgesehenen Anhangordners.");
        }

        return relativ.Replace('/', Path.DirectorySeparatorChar);
    }
}
