using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Mandanten.Domain.Persistence;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Datei-Sicherung gegen eine echte datei­basierte SQLite (VACUUM INTO
/// und das Ersetzen der Datei brauchen einen Dateipfad, kein :memory:): Export
/// liefert eine lesbare Kopie, Import stellt überschriebene Daten wieder her, und
/// eine Fremddatei wird als ungültig abgelehnt.
/// </summary>
public sealed class DatabaseBackupServiceTests : IDisposable
{
    private readonly string _dir;
    private readonly string _dbPath;
    private readonly DatabaseBackupService _service;

    public DatabaseBackupServiceTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "autobackup-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
        _dbPath = Path.Combine(_dir, "automation.db");
        _service = new DatabaseBackupService(_dbPath, NullLogger<DatabaseBackupService>.Instance);
    }

    private AutomationDbContext OeffneKontext()
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_dbPath}")
            .Options;
        return new AutomationDbContext(options);
    }

    private async Task SetzeMandantenAsync(params string[] nachnamen)
    {
        await using (var db = OeffneKontext())
        {
            await db.Database.MigrateAsync();
            db.Mandanten.RemoveRange(db.Mandanten);
            foreach (var name in nachnamen)
            {
                db.Mandanten.Add(new MandantEntity { Nachname = name });
            }

            await db.SaveChangesAsync();
        }

        // Dateihandle freigeben, damit der Dienst die Datei austauschen kann.
        SqliteConnection.ClearAllPools();
    }

    private async Task<List<string>> LeseMandantenAsync()
    {
        await using var db = OeffneKontext();
        return await db.Mandanten.Select(m => m.Nachname).OrderBy(n => n).ToListAsync();
    }

    [Fact]
    public async Task Export_ErzeugtLesbareSicherungMitDaten()
    {
        await SetzeMandantenAsync("Müller");

        var sicherung = await _service.CreateBackupFileAsync();

        try
        {
            File.Exists(sicherung).Should().BeTrue();
            await using var connection = new SqliteConnection($"Data Source={sicherung};Mode=ReadOnly");
            await connection.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT Nachname FROM Mandanten;";
            var nachname = (string?)await command.ExecuteScalarAsync();
            nachname.Should().Be("Müller");
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            File.Delete(sicherung);
        }
    }

    [Fact]
    public async Task Import_StelltUeberschriebeneDatenWiederHer()
    {
        await SetzeMandantenAsync("Müller");
        var sicherung = await _service.CreateBackupFileAsync();

        // Datenbank verändern, danach die Sicherung einspielen.
        await SetzeMandantenAsync("Schmidt");
        await using (var stream = File.OpenRead(sicherung))
        {
            await _service.ImportBackupAsync(stream);
        }

        File.Delete(sicherung);
        (await LeseMandantenAsync()).Should().ContainSingle().Which.Should().Be("Müller");
    }

    [Fact]
    public async Task Import_LegtVorImportSicherungAn()
    {
        await SetzeMandantenAsync("Müller");
        var sicherung = await _service.CreateBackupFileAsync();
        await SetzeMandantenAsync("Schmidt");

        await using (var stream = File.OpenRead(sicherung))
        {
            await _service.ImportBackupAsync(stream);
        }

        File.Delete(sicherung);
        Directory.GetFiles(_dir, "automation-vor-import-*.db.bak").Should().NotBeEmpty();
    }

    [Fact]
    public async Task Import_LehntFremddateiAb()
    {
        await SetzeMandantenAsync("Müller");
        using var muell = new MemoryStream("kein gueltiges sqlite"u8.ToArray());

        var aufruf = async () => await _service.ImportBackupAsync(muell);

        await aufruf.Should().ThrowAsync<InvalidBackupException>();
        // Bestand bleibt unangetastet.
        (await LeseMandantenAsync()).Should().ContainSingle().Which.Should().Be("Müller");
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
            // Aufräumen ist best effort; das Temp-Verzeichnis wird ohnehin recycelt.
        }
    }
}
