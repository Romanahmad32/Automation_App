using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft, dass die Sicherung die Word-Vorlagen mitnimmt.
///
/// Der Grund ist kein Ordnungssinn: die Datenbank speichert zu jeder
/// Formularvorlage <em>absolute</em> Pfade auf .docx-Dateien. Eine Sicherung
/// ohne diese Dateien ergibt nach dem Einspielen auf einem anderen Rechner
/// Formularvorlagen, die auf nichts zeigen — und das merkt der Anwalt erst,
/// wenn ein Anspruchsschreiben erzeugt werden soll.
/// </summary>
public sealed class DatabaseBackupVorlagenTests : IDisposable
{
    private readonly string _dir;
    private readonly string _dbPath;
    private readonly string _vorlagen;
    private readonly DatabaseBackupService _service;

    public DatabaseBackupVorlagenTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "autobackup-vorlagen-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
        _dbPath = Path.Combine(_dir, "automation.db");
        _vorlagen = Path.Combine(_dir, "Vorlagen");
        Directory.CreateDirectory(_vorlagen);
        _service = new DatabaseBackupService(_dbPath, _vorlagen, NullLogger<DatabaseBackupService>.Instance);
    }

    [Fact]
    public async Task Sicherung_enthaelt_die_Vorlagen_und_stellt_sie_wieder_her()
    {
        await LegeDatenbankAn();
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "Fassung des Anwalts");

        var sicherung = await _service.CreateBackupFileAsync();

        // Vorlage nach der Sicherung veraendern — wie ein Update, das
        // ueberschreibt, oder ein versehentliches Speichern.
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "kaputt");

        await using (var stream = File.OpenRead(sicherung))
        {
            await _service.ImportBackupAsync(stream);
        }

        File.Delete(sicherung);
        var inhalt = await File.ReadAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"));
        inhalt.Should().Be("Fassung des Anwalts");
    }

    [Fact]
    public async Task Zusaetzliche_Vorlagen_des_Anwenders_bleiben_beim_Einspielen_liegen()
    {
        await LegeDatenbankAn();
        var sicherung = await _service.CreateBackupFileAsync();

        // Nach der Sicherung angelegt: gehoert dem Anwender, nicht der Sicherung.
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Eigene.docx"), "neu");

        await using (var stream = File.OpenRead(sicherung))
        {
            await _service.ImportBackupAsync(stream);
        }

        File.Delete(sicherung);
        File.Exists(Path.Combine(_vorlagen, "Eigene.docx")).Should().BeTrue(
            "ein Import soll nicht loeschen, was er nicht kennt");
    }

    [Fact]
    public async Task Aeltere_Sicherung_als_blanke_Datenbankdatei_bleibt_einspielbar()
    {
        await LegeDatenbankAn();
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "unberuehrt");

        // Format vor der Umstellung: nur die .db, kein Archiv.
        var alt = Path.Combine(_dir, "alt.db");
        await SqliteSicherung.VacuumIntoAsync(_dbPath, alt);
        SqliteConnection.ClearAllPools();

        await using (var stream = File.OpenRead(alt))
        {
            await _service.ImportBackupAsync(stream);
        }

        var inhalt = await File.ReadAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"));
        inhalt.Should().Be("unberuehrt",
            "eine Sicherung ohne Vorlagen darf die vorhandenen nicht loeschen");
    }

    private async Task LegeDatenbankAn()
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_dbPath}")
            .Options;
        await using (var db = new AutomationDbContext(options))
        {
            await db.Database.MigrateAsync();
        }

        SqliteConnection.ClearAllPools();
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
            // Aufraeumen ist best effort.
        }
    }
}
