using AutomationService.Core.Persistence;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Zusage von #133 an den Bestand: <c>SchreibenNummer</c> bedeutet ab jetzt
/// „Nummer des zuletzt <b>gespeicherten</b> Schreibens". Vorgaenge, deren Nummer
/// nur vom Erzeugen stammt, verlieren sie — sonst fragte die Leiste ueber dem
/// Ausfuellformular weiter nach einer Fassung, die es nirgends gibt.
///
/// Geprueft wird gegen eine echte, dateibasierte SQLite und ueber die
/// tatsaechliche Migration, nicht gegen <c>EnsureCreated</c>: Es geht um das
/// Hochheben eines vorhandenen Bestands, und gegen ein frisch angelegtes Schema
/// waere davon nichts zu sehen. Vorbild ist <c>AppDatenOrdnerMigrationTests</c>.
/// </summary>
public sealed class SchreibenNummerMigrationTests : IDisposable
{
    const string Migration = "_SchreibenNummerNurGespeicherte";

    readonly string _dir;
    readonly string _dbPath;

    public SchreibenNummerMigrationTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "schreibennummer-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
        _dbPath = Path.Combine(_dir, "automation.db");
    }

    [Fact]
    public async Task Nie_gespeicherte_Vorgaenge_verlieren_die_Nummer_gespeicherte_behalten_sie()
    {
        await LegeBestandVorDerMigrationAnAsync();

        await using (var context = OeffneKontext())
        {
            await context.Database.MigrateAsync();
        }

        await using var db = OeffneKontext();
        var nummern = await db.Vorgaenge.AsNoTracking()
            .ToDictionaryAsync(v => v.Referenz, v => v.SchreibenNummer);

        // Erzeugt, aber nie abgelegt: Die Nummer stand fuer eine Arbeitskopie,
        // die die naechste Ablage ohnehin weggeraeumt haette.
        nummern["1/26 C03_HG-E 1"].Should().BeNull(
            "ein bloss erzeugtes Schreiben ist keines, das eine Korrektur ersetzen koennte");
        nummern["2/26 C03_HG-E 2"].Should().BeNull(
            "auch ein beantworteter Vorgang hat den Speicherschritt nie durchlaufen");

        // Ab 'abgelegt' liegt eine Fassung in der Akte — die Nummer gilt.
        nummern["3/26 C03_HG-E 3"].Should().Be(1);
        nummern["4/26 C03_HG-E 4"].Should().Be(2,
            "ein versendeter Vorgang hat erst recht gespeichert");

        // Wer nie eine Nummer hatte, bekommt auch keine.
        nummern["5/26 C03_HG-E 5"].Should().BeNull();
    }

    /// <summary>
    /// Migriert bis genau vor die neue Migration und legt die fuenf Faelle per
    /// rohem SQL an.
    ///
    /// Rohes SQL und nicht <c>db.Vorgaenge.Add</c>: EF schriebe die Spalten des
    /// <em>heutigen</em> Modells in ein Schema von damals; jede spaeter
    /// hinzukommende Spalte liesse diesen Test an einer Stelle fallen, die mit
    /// der Nummer nichts zu tun hat.
    /// </summary>
    async Task LegeBestandVorDerMigrationAnAsync()
    {
        await using (var context = OeffneKontext())
        {
            var davor = context.Database.GetMigrations()
                .TakeWhile(name => !name.EndsWith(Migration, StringComparison.Ordinal))
                .Last();
            await context.GetService<IMigrator>().MigrateAsync(davor);

            await context.Database.ExecuteSqlRawAsync(
                """
                INSERT INTO Vorgaenge (Referenz, AngefragtAm, Status, Rechtsgebiet, SchreibenNummer)
                VALUES ('1/26 C03_HG-E 1', '2026-06-12', 'erstellt',    'Verkehrsrecht', 1),
                       ('2/26 C03_HG-E 2', '2026-06-12', 'beantwortet', 'Verkehrsrecht', 3),
                       ('3/26 C03_HG-E 3', '2026-06-12', 'abgelegt',    'Verkehrsrecht', 1),
                       ('4/26 C03_HG-E 4', '2026-06-12', 'versendet',   'Verkehrsrecht', 2),
                       ('5/26 C03_HG-E 5', '2026-06-12', 'angefragt',   'Verkehrsrecht', NULL)
                """);
        }

        SqliteConnection.ClearAllPools();
    }

    AutomationDbContext OeffneKontext()
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_dbPath}")
            .Options;
        return new AutomationDbContext(options);
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
