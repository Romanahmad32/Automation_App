using System.Globalization;
using AutomationService.Core.Persistence;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Sicherung/Wiederherstellung des gesamten Anwenderbestands: Datenbank <em>und</em>
/// Word-Vorlagen, als ein ZIP (Aufbau siehe <see cref="SicherungsArchiv"/>).
///
/// Import sichert den aktuellen Stand vorher vollstaendig daneben, ersetzt
/// Datenbank und Vorlagen und hebt das Schema per EF-Core-Migrationen auf den
/// aktuellen Stand — so laesst sich auch eine aeltere Sicherung gefahrlos
/// einspielen. Blanke .db-Sicherungen aus der Zeit vor dem Vorlagenordner
/// funktionieren weiter; dann bleiben die Vorlagen unberuehrt.
///
/// Bewusst ohne DI-Kontext (nur Pfade + Logger), damit der Dienst die Dateien
/// direkt und ohne Scope-Komplikationen austauschen kann.
/// </summary>
public sealed class DatabaseBackupService(
    string databaseFilePath,
    string vorlagenVerzeichnis,
    ILogger<DatabaseBackupService> logger) : IDatabaseBackupService
{
    // Export und Import serialisieren: die Dateien werden nie gleichzeitig getauscht.
    static readonly SemaphoreSlim Gate = new(1, 1);

    public async Task<string> CreateBackupFileAsync(CancellationToken cancellationToken = default)
    {
        var zielPfad = Path.Combine(Path.GetTempPath(), $"automation-backup-{Guid.NewGuid():N}.zip");

        await Gate.WaitAsync(cancellationToken);
        try
        {
            await SicherungsArchiv.ErstelleAsync(
                databaseFilePath, vorlagenVerzeichnis, zielPfad, cancellationToken);
        }
        finally
        {
            Gate.Release();
        }

        logger.LogInformation("Sicherung erstellt: {Pfad}", zielPfad);
        return zielPfad;
    }

    public async Task ImportBackupAsync(Stream sicherung, CancellationToken cancellationToken = default)
    {
        var arbeitsordner = Path.Combine(
            Path.GetTempPath(), $"automation-import-{Guid.NewGuid():N}");
        Directory.CreateDirectory(arbeitsordner);
        var hochgeladen = Path.Combine(arbeitsordner, "sicherung");

        await Gate.WaitAsync(cancellationToken);
        try
        {
            await using (var datei = File.Create(hochgeladen))
            {
                await sicherung.CopyToAsync(datei, cancellationToken);
            }

            var (datenbankQuelle, vorlagenQuelle) = ZerlegeSicherung(hochgeladen, arbeitsordner);

            await ValidiereSicherungAsync(datenbankQuelle, cancellationToken);
            await SichereAktuellenStandAsync(cancellationToken);

            ErsetzeDatenbankdatei(datenbankQuelle);
            if (vorlagenQuelle is not null)
            {
                StelleVorlagenWiederHer(vorlagenQuelle);
            }

            await MigriereAufAktuellesSchemaAsync(cancellationToken);

            logger.LogInformation("Sicherung eingespielt und migriert.");
        }
        finally
        {
            Gate.Release();
            TryDeleteDirectory(arbeitsordner);
        }
    }

    /// <summary>
    /// Liefert Datenbank- und (falls vorhanden) Vorlagenquelle der hochgeladenen
    /// Datei — je nachdem, ob es ein Archiv oder eine blanke .db ist.
    /// </summary>
    static (string Datenbank, string? Vorlagen) ZerlegeSicherung(string hochgeladen, string arbeitsordner)
    {
        if (!SicherungsArchiv.IstArchiv(hochgeladen))
        {
            // Aeltere Sicherung: nur die Datenbank, Vorlagen bleiben unberuehrt.
            return (hochgeladen, null);
        }

        var entpackt = Path.Combine(arbeitsordner, "entpackt");
        try
        {
            SicherungsArchiv.Entpacke(hochgeladen, entpackt);
        }
        catch (InvalidDataException ex)
        {
            throw new InvalidBackupException("Die Datei ist kein lesbares Sicherungsarchiv.", ex);
        }

        var datenbank = Path.Combine(entpackt, SicherungsArchiv.DatenbankEintrag);
        if (!File.Exists(datenbank))
        {
            throw new InvalidBackupException(
                $"Im Archiv fehlt die Datenbank ({SicherungsArchiv.DatenbankEintrag}).");
        }

        var vorlagen = Path.Combine(entpackt, SicherungsArchiv.VorlagenOrdner);
        return (datenbank, Directory.Exists(vorlagen) ? vorlagen : null);
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

    /// <summary>
    /// Legt vor dem Überschreiben den vollständigen aktuellen Stand daneben —
    /// Datenbank <em>und</em> Vorlagen. Ein Import ist die einzige Stelle, an der
    /// die App fremde Daten über die eigenen legt; wer sich dabei vergreift, soll
    /// zurückkönnen.
    /// </summary>
    async Task SichereAktuellenStandAsync(CancellationToken ct)
    {
        if (!File.Exists(databaseFilePath))
        {
            return;
        }

        var bakPfad = Path.Combine(
            Path.GetDirectoryName(databaseFilePath)!,
            $"automation-vor-import-{DateTime.Now:yyyyMMdd-HHmmss}.zip");
        await SicherungsArchiv.ErstelleAsync(databaseFilePath, vorlagenVerzeichnis, bakPfad, ct);
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

    /// <summary>
    /// Spielt die Vorlagen aus der Sicherung ein. Gleichnamige werden ersetzt:
    /// die Sicherung bildet einen Stand ab, und die Datenbank verweist auf genau
    /// diese Dateien. Zusätzliche Vorlagen des Anwenders bleiben liegen.
    /// </summary>
    void StelleVorlagenWiederHer(string quellVerzeichnis)
    {
        Directory.CreateDirectory(vorlagenVerzeichnis);
        var anzahl = 0;
        foreach (var vorlage in Directory.EnumerateFiles(quellVerzeichnis, "*.docx"))
        {
            File.Copy(vorlage, Path.Combine(vorlagenVerzeichnis, Path.GetFileName(vorlage)), overwrite: true);
            anzahl++;
        }

        logger.LogInformation("{Anzahl} Vorlage(n) aus der Sicherung übernommen.", anzahl);
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

    static void TryDeleteDirectory(string pfad)
    {
        try
        {
            if (Directory.Exists(pfad))
            {
                Directory.Delete(pfad, recursive: true);
            }
        }
        catch (IOException)
        {
            // dito
        }
    }
}
