using AutomationService.Core.Persistence;
using AutomationService.Core.Persistence.HostedServices;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die automatische Sicherung vor einer Schema-Migration.
///
/// Der Anlass ist die Auslieferung: ein Update bringt Migrationen mit, die über
/// das Mandantenregister einer Kanzlei laufen. Dass vorher gesichert wird, ist
/// keine Nettigkeit, sondern die einzige Rückfahrkarte — deshalb hier gegen eine
/// echte, dateibasierte SQLite geprüft und nicht gegen :memory:.
/// </summary>
public sealed class DatabaseMigrationServiceTests : IDisposable
{
    private readonly string _dir;
    private readonly string _dbPath;

    public DatabaseMigrationServiceTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "automigration-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
        _dbPath = Path.Combine(_dir, "automation.db");
    }

    [Fact]
    public async Task Sichert_die_Datenbank_bevor_ausstehende_Migrationen_laufen()
    {
        var nachname = "Vukovic-" + Guid.NewGuid().ToString("N")[..6];
        await LegeDatenbankAufAeltestemStandAn(nachname);

        await StarteMigrationsdienstAsync();

        var sicherungen = Sicherungsdateien();
        sicherungen.Should().HaveCount(1,
            "vor einer Schemaaenderung muss genau eine Sicherung entstehen");

        // Entscheidend ist nicht, dass eine Datei da ist, sondern dass die Daten
        // darin stehen: eine leere Sicherung waere schlimmer als keine, weil man
        // sich auf sie verlassen wuerde.
        (await LeseMandantenAsync(sicherungen[0])).Should().Contain(nachname);
    }

    [Fact]
    public async Task Sichert_nicht_wenn_das_Schema_bereits_aktuell_ist()
    {
        await StarteMigrationsdienstAsync();   // legt die DB vollstaendig an
        Sicherungsdateien().Should().BeEmpty("beim ersten Start gibt es nichts zu sichern");

        await StarteMigrationsdienstAsync();   // zweiter Start, nichts ausstehend

        Sicherungsdateien().Should().BeEmpty(
            "ohne ausstehende Migration darf kein Start eine Sicherung anlegen — " +
            "sonst laeuft der Ordner mit jedem Programmstart voll");
    }

    /// <summary>
    /// Migriert bewusst nur bis zur ersten Migration, damit die uebrigen als
    /// ausstehend gelten — der Zustand, in dem ein Anwender nach einem Update ist.
    ///
    /// Der Mandant geht per rohem SQL hinein, nicht ueber
    /// <c>context.Mandanten.Add</c>: EF schriebe die Spalten des *heutigen*
    /// Modells in ein Schema von damals, und jede neue Spalte liesse diesen
    /// Test mit "table Mandanten has no column named ..." fallen — an einer
    /// Stelle, die mit der Sicherung nichts zu tun hat. Aufgezaehlt sind
    /// deshalb genau die Spalten der ersten Migration.
    /// </summary>
    private async Task LegeDatenbankAufAeltestemStandAn(string nachname)
    {
        await using (var context = OeffneKontext())
        {
            var ersteMigration = context.Database.GetMigrations().First();
            await context.GetService<IMigrator>().MigrateAsync(ersteMigration);

            await context.Database.ExecuteSqlRawAsync(
                """
                INSERT INTO Mandanten
                    (Anrede, Vorname, Nachname, StrasseHausnummer, Postleitzahl,
                     Ort, EmailAdresse, Telefonnummer, Notiz, ErstelltAm)
                VALUES ('', '', {0}, '', '', '', '', '', '', '2026-01-01')
                """,
                nachname);
        }

        SqliteConnection.ClearAllPools();
    }

    private async Task StarteMigrationsdienstAsync()
    {
        var provider = new ServiceCollection()
            .AddDbContext<AutomationDbContext>(options => options.UseSqlite($"Data Source={_dbPath}"))
            .BuildServiceProvider();

        await using (provider)
        {
            var dienst = new DatabaseMigrationService(
                provider.GetRequiredService<IServiceScopeFactory>(),
                NullLogger<DatabaseMigrationService>.Instance);

            await dienst.StartAsync(CancellationToken.None);
        }

        SqliteConnection.ClearAllPools();
    }

    private AutomationDbContext OeffneKontext()
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_dbPath}")
            .Options;
        return new AutomationDbContext(options);
    }

    private List<string> Sicherungsdateien()
    {
        var verzeichnis = Path.Combine(_dir, "Sicherungen");
        return Directory.Exists(verzeichnis)
            ? [.. Directory.GetFiles(verzeichnis, "automation-vor-migration-*.db")]
            : [];
    }

    /// <summary>
    /// Liest die Nachnamen aus einer Sicherungsdatei. Auch hier rohes SQL: Die
    /// Sicherung entsteht <b>vor</b> der Migration und traegt damit das alte
    /// Schema — eine EF-Abfrage waehlte die Spalten des heutigen Modells und
    /// liefe ins Leere.
    /// </summary>
    private static async Task<List<string>> LeseMandantenAsync(string dbPfad)
    {
        await using var verbindung = new SqliteConnection($"Data Source={dbPfad}");
        await verbindung.OpenAsync();
        var befehl = verbindung.CreateCommand();
        befehl.CommandText = "SELECT Nachname FROM Mandanten";

        var namen = new List<string>();
        await using var leser = await befehl.ExecuteReaderAsync();
        while (await leser.ReadAsync())
        {
            namen.Add(leser.GetString(0));
        }
        return namen;
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        try
        {
            Directory.Delete(_dir, recursive: true);
        }
        catch (IOException)
        {
            // Temp-Ordner: ein zurueckbleibendes Handle darf den Test nicht roten.
        }
    }
}
