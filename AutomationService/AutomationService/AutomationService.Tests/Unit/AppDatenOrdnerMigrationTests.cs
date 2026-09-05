using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Zusage von #103 an den Bestand: Wer schon vier Ordner gewaehlt hat,
/// arbeitet nach dem Update unveraendert weiter. Der neue App-Daten-Ordner ist
/// ein Angebot, kein Umzug — es wird keine Datei verschoben und keine
/// Einstellung umgeschrieben.
///
/// Geprueft wird gegen eine echte, dateibasierte SQLite und ueber die
/// tatsaechliche Migration, nicht gegen <c>EnsureCreated</c>: Der Fehler, um den
/// es geht, entsteht beim Hochheben eines vorhandenen Schemas und waere gegen
/// ein frisch angelegtes unsichtbar.
/// </summary>
public sealed class AppDatenOrdnerMigrationTests : IDisposable
{
    const string Akten = @"C:\Alt\Akten";
    const string Register = @"C:\Alt\Register";
    const string Vorlagen = @"C:\Alt\Vorlagen";
    const string Sicherungen = @"C:\Alt\Sicherungen";

    readonly string _dir;
    readonly string _dbPath;

    public AppDatenOrdnerMigrationTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "appdatenordner-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
        _dbPath = Path.Combine(_dir, "automation.db");
    }

    [Fact]
    public async Task Ein_Bestand_mit_vier_gesetzten_Ordnern_laeuft_nach_der_Migration_unveraendert()
    {
        await LegeBestandVorDerMigrationAnAsync();

        await using (var context = OeffneKontext())
        {
            await context.Database.MigrateAsync();
        }

        await using var db = OeffneKontext();
        var settings = await db.KanzleiSettings.AsNoTracking()
            .SingleAsync(s => s.Id == KanzleiSettingsEntity.SingletonId);

        settings.AppDatenOrdner.Should().BeEmpty(
            "die Migration darf keinen Ordner erfinden — gewaehlt wird er in den Einstellungen");
        settings.AktenStammordner.Should().Be(Akten);
        settings.RegisterAblageOrdner.Should().Be(Register);
        settings.VorlagenOrdner.Should().Be(Vorlagen);
        settings.SicherungsAblageOrdner.Should().Be(Sicherungen);

        // Und der Punkt, an dem es sich entscheidet: Die Vorgaben, an denen
        // WordAutomation, Backup und der Register-Spiegel haengen, liefern nach
        // der Umstellung dieselben Ordner wie vorher.
        VorlagenOrdnerVorgabe.Ermittle(db).Should().Be(Vorlagen);
        RegisterAblageVorgabe.Ermittle(db).Should().Be(Register);
        SicherungsAblageVorgabe.Ermittle(db).Should().Be(Sicherungen);
    }

    /// <summary>
    /// Migriert bis genau vor die AppDatenOrdner-Migration und legt den
    /// Einstellungssatz per rohem SQL an.
    ///
    /// Rohes SQL und nicht <c>db.KanzleiSettings.Add</c>: EF schriebe die
    /// Spalten des <em>heutigen</em> Modells in ein Schema von damals und liesse
    /// den Test mit "table KanzleiSettings has no column named AppDatenOrdner"
    /// fallen — ausgerechnet an der Stelle, die er pruefen soll.
    /// </summary>
    async Task LegeBestandVorDerMigrationAnAsync()
    {
        await using (var context = OeffneKontext())
        {
            var davor = context.Database.GetMigrations()
                .TakeWhile(name => !name.EndsWith("_AppDatenOrdner", StringComparison.Ordinal))
                .Last();
            await context.GetService<IMigrator>().MigrateAsync(davor);

            await context.Database.ExecuteSqlRawAsync(
                """
                INSERT INTO KanzleiSettings
                    (Id, Personentyp, Name, StrasseHausnummer, Postleitzahl, Ort,
                     EmailAdresse, Telefonnummer, LaufendeAuftragsnummer, Abteilung,
                     TabellenkopfFarbeHex, AktenStammordner, RegisterAblageOrdner,
                     VorlagenOrdner, SicherungsAblageOrdner)
                VALUES (1, 'Rechtsanwalt', 'Kanzlei Muster', '', '', '', '', '', 7, 'C03',
                        'D9D9D9', {0}, {1}, {2}, {3})
                """,
                Akten, Register, Vorlagen, Sicherungen);
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
