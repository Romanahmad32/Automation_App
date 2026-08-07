using AutomationService.Core.Persistence;
using AutomationService.Core.Persistence.HostedServices;
using AutomationService.Features.Mandanten.Domain.Persistence;
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
    /// </summary>
    private async Task LegeDatenbankAufAeltestemStandAn(string nachname)
    {
        await using (var context = OeffneKontext())
        {
            var ersteMigration = context.Database.GetMigrations().First();
            await context.GetService<IMigrator>().MigrateAsync(ersteMigration);

            context.Mandanten.Add(new MandantEntity { Nachname = nachname });
            await context.SaveChangesAsync();
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

    private static async Task<List<string>> LeseMandantenAsync(string dbPfad)
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={dbPfad}")
            .Options;
        await using var context = new AutomationDbContext(options);
        return await context.Mandanten.Select(m => m.Nachname).ToListAsync();
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
