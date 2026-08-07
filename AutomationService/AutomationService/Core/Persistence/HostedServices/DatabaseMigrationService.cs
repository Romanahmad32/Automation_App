using System.Globalization;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Core.Persistence.HostedServices;

/// <summary>
/// Bringt die SQLite-Datenbank beim Start auf den aktuellen Schemastand und
/// aktiviert den WAL-Journalmodus. Läuft — anders als die Warmup-Dienste —
/// <em>blockierend</em> im StartAsync, bevor der Host Requests annimmt: die
/// übrigen Dienste (Postfach-Monitor, Controller) dürfen erst auf eine fertig
/// migrierte Datenbank zugreifen.
///
/// Stehen Migrationen an, wird die Datenbank vorher gesichert. Der Anlass ist
/// die Auslieferung neuer Versionen: ein Update bringt die Migration mit, und
/// eine Schemaänderung, die schiefgeht oder ungewollt Daten verwirft, trifft
/// hier das Mandantenregister einer Kanzlei. Ein fehlgeschlagenes Update ist
/// verschmerzbar, eine halb migrierte Datenbank nicht.
/// </summary>
public sealed class DatabaseMigrationService(
    IServiceScopeFactory scopeFactory,
    ILogger<DatabaseMigrationService> logger) : IHostedService
{
    /// <summary>So viele automatische Sicherungen bleiben erhalten.</summary>
    public const int AufbewahrteSicherungen = 5;

    private const string Suchmuster = "automation-vor-migration-*.db";

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AutomationDbContext>();

        var ausstehend = (await dbContext.Database.GetPendingMigrationsAsync(cancellationToken)).ToList();
        if (ausstehend.Count > 0)
        {
            // Der Pfad kommt aus der Verbindung des Kontexts, nicht aus
            // AppDataPaths: gesichert werden muss genau die Datei, die gleich
            // migriert wird — sonst sichert der Dienst im Test (oder bei einer
            // abweichenden Konfiguration) eine andere Datenbank als die, die er
            // anfasst.
            await SichereVorMigrationAsync(
                dbContext.Database.GetDbConnection().DataSource,
                ausstehend,
                cancellationToken);
        }

        await dbContext.Database.MigrateAsync(cancellationToken);

        // WAL erlaubt gleichzeitiges Lesen während eines Schreibvorgangs und ist
        // robuster gegen Abstürze. Einmal gesetzt, bleibt der Modus persistent in
        // der Datei — das erneute Setzen bei jedem Start ist unschädlich.
        await dbContext.Database.ExecuteSqlRawAsync("PRAGMA journal_mode=WAL;", cancellationToken);

        logger.LogInformation("SQLite-Datenbank migriert und einsatzbereit (WAL aktiv).");
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    private async Task SichereVorMigrationAsync(
        string datenbank,
        List<string> ausstehend,
        CancellationToken cancellationToken)
    {
        if (!File.Exists(datenbank))
        {
            // Erster Start: es gibt noch nichts zu sichern.
            return;
        }

        // Neben der Datenbank, also in %APPDATA%\AutomationService\Sicherungen —
        // ausserhalb des Installationsverzeichnisses. Eine Sicherung, die ein
        // Update mitentfernt, waere keine.
        var verzeichnis = Directory.CreateDirectory(
            Path.Combine(Path.GetDirectoryName(datenbank)!, "Sicherungen")).FullName;
        var zeitstempel = DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
        var ziel = Path.Combine(verzeichnis, $"automation-vor-migration-{zeitstempel}.db");

        try
        {
            await SqliteSicherung.VacuumIntoAsync(datenbank, ziel, cancellationToken);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or Microsoft.Data.Sqlite.SqliteException)
        {
            // Bewusst abbrechen statt ungesichert migrieren: Ohne Sicherung ist
            // eine misslungene Migration nicht mehr rückgängig zu machen. Der
            // Start scheitert mit dieser Meldung, die das Frontend anzeigt —
            // die Ursache (volle Platte, fehlende Rechte) muss der Anwender
            // ohnehin beheben.
            throw new InvalidOperationException(
                $"Die Datenbank konnte vor der Aktualisierung nicht gesichert werden ({ziel}). " +
                "Die Aktualisierung wurde abgebrochen, damit keine ungesicherten Daten verändert werden.",
                ex);
        }

        logger.LogInformation(
            "Vor {Anzahl} ausstehenden Migrationen ({Migrationen}) gesichert nach {Pfad}.",
            ausstehend.Count,
            string.Join(", ", ausstehend),
            ziel);

        SqliteSicherung.RaeumeAelteSicherungenAuf(verzeichnis, Suchmuster, AufbewahrteSicherungen);
    }
}
