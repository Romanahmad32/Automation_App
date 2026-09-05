using System.Globalization;
using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
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
/// direkt und ohne Scope-Komplikationen austauschen kann. Der Vorlagenordner
/// kommt als Funktion statt als fester Wert: er ist eine Einstellung (#33) und
/// wird je Operation genau einmal aufgeloest — beim Import zwingend, bevor die
/// Datenbank getauscht wird, sonst laese man den Ordner aus der fremden DB.
/// </summary>
public sealed class DatabaseBackupService(
    string databaseFilePath,
    Func<string> vorlagenVerzeichnis,
    ILogger<DatabaseBackupService> logger) : IDatabaseBackupService
{
    // Export und Import serialisieren: die Dateien werden nie gleichzeitig getauscht.
    static readonly SemaphoreSlim Gate = new(1, 1);

    public async Task<string> CreateBackupFileAsync(CancellationToken cancellationToken = default)
    {
        var zielPfad = Path.Combine(Path.GetTempPath(), $"automation-backup-{Guid.NewGuid():N}.zip");
        var vorlagenOrdner = vorlagenVerzeichnis();

        await Gate.WaitAsync(cancellationToken);
        try
        {
            await SicherungsArchiv.ErstelleAsync(
                databaseFilePath, vorlagenOrdner, zielPfad, cancellationToken);
        }
        finally
        {
            Gate.Release();
        }

        logger.LogInformation("Sicherung erstellt: {Pfad}", zielPfad);
        return zielPfad;
    }

    public async Task<SicherungsImportErgebnis> ImportBackupAsync(
        Stream sicherung, CancellationToken cancellationToken = default)
    {
        var arbeitsordner = Path.Combine(
            Path.GetTempPath(), $"automation-import-{Guid.NewGuid():N}");
        Directory.CreateDirectory(arbeitsordner);
        var hochgeladen = Path.Combine(arbeitsordner, "sicherung");

        // Vor dem Datenbanktausch aufloesen: der Ordner ist eine Einstellung
        // und muss aus der EIGENEN Datenbank kommen, nicht aus der eingespielten.
        var vorlagenOrdner = vorlagenVerzeichnis();

        await Gate.WaitAsync(cancellationToken);
        try
        {
            await using (var datei = File.Create(hochgeladen))
            {
                await sicherung.CopyToAsync(datei, cancellationToken);
            }

            var (datenbankQuelle, vorlagenQuelle) = ZerlegeSicherung(hochgeladen, arbeitsordner);

            await ValidiereSicherungAsync(datenbankQuelle, cancellationToken);
            await SichereAktuellenStandAsync(vorlagenOrdner, cancellationToken);

            // Vor dem Tausch aus der EIGENEN Datenbank lesen: die Pfadfelder
            // dieses Rechners sollen den Import ueberleben.
            var lokaleEinstellungen = await LeseLokaleEinstellungenAsync(cancellationToken);

            ErsetzeDatenbankdatei(datenbankQuelle);
            IReadOnlyList<string> uebersprungen = vorlagenQuelle is null
                ? []
                : VorlagenWiederherstellung.StelleWiederHer(vorlagenQuelle, vorlagenOrdner);
            if (uebersprungen.Count > 0)
            {
                logger.LogInformation(
                    "{Anzahl} Vorlage(n) nicht ersetzt (lokal abweichender Inhalt): {Namen}",
                    uebersprungen.Count, string.Join(", ", uebersprungen));
            }

            await MigriereAufAktuellesSchemaAsync(cancellationToken);
            await SchuetzeMaschinenPfadeAsync(lokaleEinstellungen, cancellationToken);

            logger.LogInformation("Sicherung eingespielt und migriert.");
            return new SicherungsImportErgebnis(uebersprungen);
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
    async Task SichereAktuellenStandAsync(string vorlagenOrdner, CancellationToken ct)
    {
        if (!File.Exists(databaseFilePath))
        {
            return;
        }

        var bakPfad = Path.Combine(
            Path.GetDirectoryName(databaseFilePath)!,
            $"automation-vor-import-{DateTime.Now:yyyyMMdd-HHmmss}.zip");
        await SicherungsArchiv.ErstelleAsync(databaseFilePath, vorlagenOrdner, bakPfad, ct);
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
        await using var context = OeffneKontext();
        await context.Database.MigrateAsync(ct);
        await context.Database.ExecuteSqlRawAsync("PRAGMA journal_mode=WAL;", ct);
    }

    /// <summary>Der Einstellungssatz dieses Rechners — oder null, wenn es (noch) keinen gibt.</summary>
    async Task<KanzleiSettingsEntity?> LeseLokaleEinstellungenAsync(CancellationToken ct)
    {
        if (!File.Exists(databaseFilePath))
        {
            return null;
        }

        await using var context = OeffneKontext();
        return await context.KanzleiSettings.AsNoTracking()
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, ct);
    }

    /// <summary>
    /// Setzt nach dem Import die maschinen<em>abhängigen</em> Pfadfelder auf die
    /// Werte dieses Rechners zurück. Gab es lokal keinen Einstellungssatz,
    /// werden sie geleert — fremde Maschinenpfade dürfen den Import nicht
    /// überleben. Läuft nach der Migration, weil eine ältere Sicherung die
    /// Spalten VorlagenOrdner, SicherungsAblageOrdner und AppDatenOrdner erst
    /// danach hat.
    ///
    /// Maßgeblich ist seit #103 die <b>Form</b> des Werts, nicht mehr das Feld
    /// (<see cref="AppOrdnerPfad"/>):
    ///
    /// * <b>absolut</b> (<c>C:\Users\Meier\OneDrive - Kanzlei\…</c>) —
    ///   ausgenommen wie bisher. Zwar zeigen beide Rechner auf <em>denselben</em>
    ///   synchronisierten Ordner, aber unter verschiedenen Pfaden. Würde der
    ///   fremde übernommen, legte dieser Rechner seine Sicherungen woanders ab,
    ///   als er sein Angebot liest — die Übergabe wäre nach dem ersten
    ///   Einspielen still kaputt.
    /// * <b>relativ mit Anker</b> (<c>%OneDriveCommercial%\Kanzlei App
    ///   Daten</c>) — kommt mit. Genau dafür ist die Form da: Sie trägt keinen
    ///   Benutzernamen und kein Laufwerk, sondern den Namen der Variable, die
    ///   der OneDrive-Client auf jedem Rechner selbst setzt. Sie auszunehmen
    ///   hieße, den zweiten Arbeitsplatz wieder alles einstellen zu lassen —
    ///   der Grund, aus dem #103 überhaupt existiert.
    ///
    /// Ist der Anker auf diesem Rechner nicht gesetzt, wird der Wert trotzdem
    /// übernommen: Er bleibt richtig, sobald das Konto eingerichtet ist, und bis
    /// dahin sagt <c>GET api/Settings/ordner</c>, was fehlt. Ihn zu verwerfen
    /// wäre stiller Datenverlust an einer behebbaren Lage.
    /// </summary>
    async Task SchuetzeMaschinenPfadeAsync(KanzleiSettingsEntity? lokal, CancellationToken ct)
    {
        await using var context = OeffneKontext();
        var eingespielt = await context.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, ct);
        if (eingespielt is null)
        {
            return;
        }

        eingespielt.AppDatenOrdner = Uebernommen(eingespielt.AppDatenOrdner, lokal?.AppDatenOrdner);
        eingespielt.AktenStammordner = Uebernommen(eingespielt.AktenStammordner, lokal?.AktenStammordner);
        eingespielt.RegisterAblageOrdner =
            Uebernommen(eingespielt.RegisterAblageOrdner, lokal?.RegisterAblageOrdner);
        eingespielt.VorlagenOrdner = Uebernommen(eingespielt.VorlagenOrdner, lokal?.VorlagenOrdner);
        eingespielt.SicherungsAblageOrdner =
            Uebernommen(eingespielt.SicherungsAblageOrdner, lokal?.SicherungsAblageOrdner);
        await context.SaveChangesAsync(ct);
    }

    /// <summary>Der eingespielte Wert, wenn er relativ ist — sonst der lokale.</summary>
    static string Uebernommen(string eingespielt, string? lokal) =>
        AppOrdnerPfad.IstRelativ(eingespielt) ? eingespielt.Trim() : lokal ?? string.Empty;

    AutomationDbContext OeffneKontext()
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={databaseFilePath}")
            .Options;
        return new AutomationDbContext(options);
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
