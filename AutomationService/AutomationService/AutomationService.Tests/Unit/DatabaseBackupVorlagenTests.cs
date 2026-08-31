using System.IO.Compression;
using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft, dass die Sicherung die Word-Vorlagen mitnimmt — und sie beim
/// Einspielen <em>schonend</em> wiederherstellt (#33): Fehlendes kommt zurück
/// (samt Unterordnern), Identisches wird still übersprungen, lokal
/// Abweichendes bleibt liegen und wird gemeldet. Die frühere Erwartung
/// „gleichnamige werden ersetzt" ist mit #33 ausdrücklich umgestellt: der
/// lokale Stand könnte der neuere sein, still überschreiben wäre genau der
/// Datenverlust, vor dem die Sicherung schützen soll.
///
/// Dazu die zweite Zusage von #33: maschinenabhängige Ordnerpfade in den
/// Einstellungen überleben den Import mit den Werten <em>dieses</em> Rechners.
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
        _service = new DatabaseBackupService(_dbPath, () => _vorlagen, NullLogger<DatabaseBackupService>.Instance);
    }

    [Fact]
    public async Task Fehlende_Vorlage_wird_aus_der_Sicherung_wiederhergestellt()
    {
        await LegeDatenbankAn();
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "Fassung des Anwalts");

        var sicherung = await _service.CreateBackupFileAsync();
        File.Delete(Path.Combine(_vorlagen, "Anspruch.docx"));

        var ergebnis = await Importiere(sicherung);

        ergebnis.UebersprungeneVorlagen.Should().BeEmpty();
        var inhalt = await File.ReadAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"));
        inhalt.Should().Be("Fassung des Anwalts");
    }

    [Fact]
    public async Task Abweichende_lokale_Vorlage_bleibt_liegen_und_wird_gemeldet()
    {
        await LegeDatenbankAn();
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "Fassung des Anwalts");

        var sicherung = await _service.CreateBackupFileAsync();

        // Nach der Sicherung weiterbearbeitet — der lokale Stand ist der neuere.
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "weiterbearbeitet");

        var ergebnis = await Importiere(sicherung);

        ergebnis.UebersprungeneVorlagen.Should().ContainSingle().Which.Should().Be("Anspruch.docx");
        var inhalt = await File.ReadAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"));
        inhalt.Should().Be("weiterbearbeitet", "still ueberschreiben waere Datenverlust");
    }

    [Fact]
    public async Task Identische_Vorlage_wird_still_uebersprungen()
    {
        await LegeDatenbankAn();
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "unveraendert");

        var sicherung = await _service.CreateBackupFileAsync();
        var ergebnis = await Importiere(sicherung);

        ergebnis.UebersprungeneVorlagen.Should().BeEmpty();
    }

    [Fact]
    public async Task Unterordner_werden_rekursiv_gepackt_und_wiederhergestellt()
    {
        await LegeDatenbankAn();
        Directory.CreateDirectory(Path.Combine(_vorlagen, "Unfall"));
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Unfall", "Anspruch.docx"), "im Unterordner");

        var sicherung = await _service.CreateBackupFileAsync();
        Directory.Delete(Path.Combine(_vorlagen, "Unfall"), recursive: true);

        await Importiere(sicherung);

        var inhalt = await File.ReadAllTextAsync(Path.Combine(_vorlagen, "Unfall", "Anspruch.docx"));
        inhalt.Should().Be("im Unterordner");
    }

    [Fact]
    public async Task Word_Sperrdateien_landen_nicht_im_Archiv()
    {
        await LegeDatenbankAn();
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "echt");
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "~$Anspruch.docx"), "Sperrdatei");

        var sicherung = await _service.CreateBackupFileAsync();

        using (var archiv = ZipFile.OpenRead(sicherung))
        {
            archiv.Entries.Select(e => e.FullName).Should().NotContain(n => n.Contains("~$"));
        }

        File.Delete(sicherung);
    }

    [Fact]
    public async Task Zusaetzliche_Vorlagen_des_Anwenders_bleiben_beim_Einspielen_liegen()
    {
        await LegeDatenbankAn();
        var sicherung = await _service.CreateBackupFileAsync();

        // Nach der Sicherung angelegt: gehoert dem Anwender, nicht der Sicherung.
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Eigene.docx"), "neu");

        await Importiere(sicherung);

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

    [Fact]
    public async Task Wiederherstellen_ueberschreibt_die_eingestellten_Ordnerpfade_nicht()
    {
        await LegeDatenbankAn();
        await SchreibeOrdnerEinstellungen(
            akten: @"D:\Fremd\Akten", register: @"D:\Fremd\Register",
            vorlagen: @"D:\Fremd\Vorlagen", sicherungen: @"D:\Fremd\Sicherungen");
        var sicherung = await _service.CreateBackupFileAsync();

        // Der lokale Rechner hat eigene Pfade — die muessen den Import ueberleben.
        await SchreibeOrdnerEinstellungen(
            akten: @"C:\Lokal\Akten", register: @"C:\Lokal\Register",
            vorlagen: @"C:\Lokal\Vorlagen", sicherungen: @"C:\Lokal\Sicherungen");

        await Importiere(sicherung);

        var settings = await LiesEinstellungen();
        settings.AktenStammordner.Should().Be(@"C:\Lokal\Akten");
        settings.RegisterAblageOrdner.Should().Be(@"C:\Lokal\Register");
        settings.VorlagenOrdner.Should().Be(@"C:\Lokal\Vorlagen");
        settings.SicherungsAblageOrdner.Should().Be(@"C:\Lokal\Sicherungen",
            "sonst legt dieser Rechner seine Sicherungen woanders ab, als er sein Angebot liest");
    }

    private async Task<SicherungsImportErgebnis> Importiere(string sicherung)
    {
        SicherungsImportErgebnis ergebnis;
        await using (var stream = File.OpenRead(sicherung))
        {
            ergebnis = await _service.ImportBackupAsync(stream);
        }

        File.Delete(sicherung);
        return ergebnis;
    }

    private async Task SchreibeOrdnerEinstellungen(
        string akten, string register, string vorlagen, string sicherungen)
    {
        await using var db = OeffneKontext();
        var settings = await db.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId);
        if (settings is null)
        {
            settings = KanzleiSettingsRepository.CreateDefault();
            db.KanzleiSettings.Add(settings);
        }

        settings.AktenStammordner = akten;
        settings.RegisterAblageOrdner = register;
        settings.VorlagenOrdner = vorlagen;
        settings.SicherungsAblageOrdner = sicherungen;
        await db.SaveChangesAsync();
        SqliteConnection.ClearAllPools();
    }

    private async Task<KanzleiSettingsEntity> LiesEinstellungen()
    {
        await using var db = OeffneKontext();
        return await db.KanzleiSettings.AsNoTracking()
            .SingleAsync(s => s.Id == KanzleiSettingsEntity.SingletonId);
    }

    private AutomationDbContext OeffneKontext()
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_dbPath}")
            .Options;
        return new AutomationDbContext(options);
    }

    private async Task LegeDatenbankAn()
    {
        await using (var db = OeffneKontext())
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
