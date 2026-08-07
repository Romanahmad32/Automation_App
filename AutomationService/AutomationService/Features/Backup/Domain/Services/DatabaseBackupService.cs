using System.Globalization;
using AutomationService.Core.Persistence;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Datei-Sicherung/-Wiederherstellung der eingebetteten SQLite-Datenbank.
///
/// Export nutzt <c>VACUUM INTO</c> (statt die laufende Datei roh zu kopieren),
/// damit auch im WAL-Betrieb eine in sich stimmige Einzeldatei ohne Seiten­dateien
/// (-wal/-shm) entsteht. Import sichert den aktuellen Stand vorher als .bak-Datei
/// daneben, ersetzt die Datenbankdatei und hebt sie per EF-Core-Migrationen auf
/// den aktuellen Schemastand — so lässt sich auch eine ältere Sicherung gefahrlos
/// einspielen.
///
/// Bewusst ohne DI-Kontext (nur Pfad + Logger), damit der Dienst die Datei direkt
/// und ohne Scope-Komplikationen austauschen kann.
/// </summary>
public sealed class DatabaseBackupService(
    string databaseFilePath,
    ILogger<DatabaseBackupService> logger) : IDatabaseBackupService
{
    // Export und Import serialisieren: die Datei wird nie gleichzeitig getauscht.
    static readonly SemaphoreSlim Gate = new(1, 1);

    public async Task<string> CreateBackupFileAsync(CancellationToken cancellationToken = default)
    {
        var zielPfad = Path.Combine(Path.GetTempPath(), $"automation-backup-{Guid.NewGuid():N}.db");

        await Gate.WaitAsync(cancellationToken);
        try
        {
            await SqliteSicherung.VacuumIntoAsync(databaseFilePath, zielPfad, cancellationToken);
        }
        finally
        {
            Gate.Release();
        }

        logger.LogInformation("Datenbank-Sicherung erstellt: {Pfad}", zielPfad);
        return zielPfad;
    }

    public async Task ImportBackupAsync(Stream sicherung, CancellationToken cancellationToken = default)
    {
        var importPfad = Path.Combine(Path.GetTempPath(), $"automation-import-{Guid.NewGuid():N}.db");

        await Gate.WaitAsync(cancellationToken);
        try
        {
            await using (var datei = File.Create(importPfad))
            {
                await sicherung.CopyToAsync(datei, cancellationToken);
            }

            await ValidiereSicherungAsync(importPfad, cancellationToken);
            await SichereAktuellenStandAsync(cancellationToken);
            ErsetzeDatenbankdatei(importPfad);
            await MigriereAufAktuellesSchemaAsync(cancellationToken);

            logger.LogInformation("Datenbank-Sicherung eingespielt und migriert.");
        }
        finally
        {
            Gate.Release();
            TryDelete(importPfad);
        }
    }

    /// <summary>Stellt sicher, dass die Datei eine lesbare SQLite-DB dieser App ist.</summary>
    static async Task ValidiereSicherungAsync(string pfad, CancellationToken ct)
    {
        try
        {
            await using var connection = new SqliteConnection($"Data Source={pfad};Mode=ReadOnly");
            await connection.OpenAsync(ct);
            await using var command = connection.CreateCommand();
            command.CommandText =
                "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='__EFMigrationsHistory';";
            var treffer = Convert.ToInt64(
                await command.ExecuteScalarAsync(ct),
                CultureInfo.InvariantCulture);
            if (treffer == 0)
            {
                throw new InvalidBackupException(
                    "Die Datei ist keine gültige Sicherung dieser Anwendung (Migrationsverlauf fehlt).");
            }
        }
        catch (SqliteException ex)
        {
            throw new InvalidBackupException("Die Datei ist keine lesbare SQLite-Datenbank.", ex);
        }
    }

    /// <summary>Legt vor dem Überschreiben eine .bak-Kopie der aktuellen DB daneben ab.</summary>
    async Task SichereAktuellenStandAsync(CancellationToken ct)
    {
        if (!File.Exists(databaseFilePath))
        {
            return;
        }

        var bakPfad = Path.Combine(
            Path.GetDirectoryName(databaseFilePath)!,
            $"automation-vor-import-{DateTime.Now:yyyyMMdd-HHmmss}.db.bak");
        await SqliteSicherung.VacuumIntoAsync(databaseFilePath, bakPfad, ct);
        logger.LogInformation("Vor-Import-Sicherung abgelegt: {Pfad}", bakPfad);
    }

    /// <summary>Tauscht die Datenbankdatei aus, nachdem alle Verbindungen gelöst sind.</summary>
    void ErsetzeDatenbankdatei(string quelle)
    {
        // Gepoolte Verbindungen halten sonst ein Handle auf die Zieldatei und
        // verhindern das Überschreiben; veraltete WAL-/SHM-Seitendateien entfernen.
        SqliteConnection.ClearAllPools();
        TryDelete(databaseFilePath + "-wal");
        TryDelete(databaseFilePath + "-shm");
        File.Copy(quelle, databaseFilePath, overwrite: true);
    }

    /// <summary>Hebt die (ggf. ältere) eingespielte DB auf den aktuellen Schemastand.</summary>
    async Task MigriereAufAktuellesSchemaAsync(CancellationToken ct)
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={databaseFilePath}")
            .Options;
        await using var context = new AutomationDbContext(options);
        await context.Database.MigrateAsync(ct);
        await context.Database.ExecuteSqlRawAsync("PRAGMA journal_mode=WAL;", ct);
    }

    static void TryDelete(string pfad)
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
            // Best effort: temporäre/Seitendateien werden notfalls später überschrieben.
        }
    }
}
