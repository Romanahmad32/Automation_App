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
/// Was von den Ordnereinstellungen bei der Arbeitsplatz-Uebergabe mitkommt
/// (§7.2, #39, #103) — und dass die Sicherung die Vorlagen auch dann findet,
/// wenn nur der App-Daten-Ordner gesetzt ist.
///
/// #39 nahm alle Ordnerpfade von der Uebernahme aus, weil sie maschinenabhaengig
/// waren. Fuer die relative Speicherform traegt diese Begruendung nicht mehr:
/// <c>%OneDriveCommercial%\Kanzlei App Daten</c> meint auf beiden Rechnern
/// denselben Ordner. Sie auszunehmen hiesse, den zweiten Arbeitsplatz wieder
/// alles einstellen zu lassen — genau das, was #103 abschafft.
/// </summary>
public sealed class OrdnerUebernahmeTests : IDisposable
{
    const string Relativ = @"%OneDriveCommercial%\Kanzlei App Daten";

    readonly string _dir;
    readonly string _dbPath;
    readonly string _appDaten;
    readonly DatabaseBackupService _service;

    public OrdnerUebernahmeTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "ordneruebernahme-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_dir);
        _dbPath = Path.Combine(_dir, "automation.db");
        _appDaten = Path.Combine(_dir, "Kanzlei App Daten");
        _service = new DatabaseBackupService(
            _dbPath, VorlagenOrdnerAusDenEinstellungen, NullLogger<DatabaseBackupService>.Instance);
    }

    /// <summary>
    /// Der Schnitt von #103: nach Form, nicht nach Feld. Beide Zusagen in einem
    /// Test, weil sie nur zusammen etwas bedeuten — kaeme das Relative nicht mit,
    /// waere die Speicherform sinnlos; kaeme das Absolute mit, legte dieser
    /// Rechner seine Sicherungen woanders ab, als er sein Angebot liest.
    /// </summary>
    [Fact]
    public async Task Relative_Ordner_kommen_mit_absolute_bleiben_lokal()
    {
        await LegeDatenbankAnAsync();
        await SchreibeOrdnerAsync(
            appDaten: Relativ, akten: @"D:\Fremd\Akten", vorlagen: @"D:\Fremd\Vorlagen");
        var sicherung = await _service.CreateBackupFileAsync();

        await SchreibeOrdnerAsync(
            appDaten: @"%OneDriveCommercial%\Woanders",
            akten: @"C:\Lokal\Akten",
            vorlagen: @"C:\Lokal\Vorlagen");

        await ImportiereAsync(sicherung);

        var settings = await LiesEinstellungenAsync();
        settings.AppDatenOrdner.Should().Be(Relativ,
            "eine relative Angabe traegt ihren Anker mit und meint hier denselben Ordner");
        settings.AktenStammordner.Should().Be(@"C:\Lokal\Akten");
        settings.VorlagenOrdner.Should().Be(@"C:\Lokal\Vorlagen",
            "ein absoluter Pfad des anderen Rechners zeigt hier ins Leere");
    }

    /// <summary>
    /// Der Anwalt hat einen Ordner gewaehlt, sonst nichts. Die Sicherung muss die
    /// Vorlagen trotzdem finden — unter dem abgeleiteten
    /// <c>&lt;AppDaten&gt;\Vorlagen</c>. Sonst waere ein Archiv entstanden, das
    /// aussieht wie eine vollstaendige Sicherung und keine ist.
    /// </summary>
    [Fact]
    public async Task SicherungsArchiv_findet_die_Vorlagen_unter_dem_App_Daten_Ordner()
    {
        await LegeDatenbankAnAsync();
        await SchreibeOrdnerAsync(appDaten: _appDaten, akten: string.Empty, vorlagen: string.Empty);

        var vorlagen = Path.Combine(_appDaten, AppDatenOrdnerVorgabe.VorlagenUnterordner);
        Directory.CreateDirectory(vorlagen);
        await File.WriteAllTextAsync(Path.Combine(vorlagen, "Anspruch.docx"), "Vorlage");

        var sicherung = await _service.CreateBackupFileAsync();

        using (var archiv = ZipFile.OpenRead(sicherung))
        {
            archiv.Entries.Select(e => e.FullName).Should()
                .Contain($"{SicherungsArchiv.VorlagenOrdner}/Anspruch.docx");
        }

        File.Delete(sicherung);
    }

    string VorlagenOrdnerAusDenEinstellungen()
    {
        using var db = OeffneKontext();
        var ordner = VorlagenOrdnerVorgabe.Ermittle(db);
        SqliteConnection.ClearAllPools();
        return ordner;
    }

    async Task ImportiereAsync(string sicherung)
    {
        await using (var stream = File.OpenRead(sicherung))
        {
            await _service.ImportBackupAsync(stream);
        }

        File.Delete(sicherung);
    }

    async Task SchreibeOrdnerAsync(string appDaten, string akten, string vorlagen)
    {
        await using var db = OeffneKontext();
        var settings = await db.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId);
        if (settings is null)
        {
            settings = KanzleiSettingsRepository.CreateDefault();
            db.KanzleiSettings.Add(settings);
        }

        settings.AppDatenOrdner = appDaten;
        settings.AktenStammordner = akten;
        settings.VorlagenOrdner = vorlagen;
        await db.SaveChangesAsync();
        SqliteConnection.ClearAllPools();
    }

    async Task<KanzleiSettingsEntity> LiesEinstellungenAsync()
    {
        await using var db = OeffneKontext();
        return await db.KanzleiSettings.AsNoTracking()
            .SingleAsync(s => s.Id == KanzleiSettingsEntity.SingletonId);
    }

    async Task LegeDatenbankAnAsync()
    {
        await using (var db = OeffneKontext())
        {
            await db.Database.MigrateAsync();
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
