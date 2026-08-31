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
/// Die Übergabe zwischen zwei Arbeitsplätzen (#39) — das eigentliche Stück.
///
/// Ein Sicherungsordner ohne diese Rückfrage wäre eine Falle: Man spielt montags
/// im Büro einen Stand von Freitag ein und überschreibt die Arbeit vom
/// Wochenende. Geprüft wird deshalb beides — dass ein neuerer fremder Stand
/// angeboten wird <em>und</em> dass ein älterer es nicht wird.
/// </summary>
public sealed class ArbeitsplatzUebergabeTests : IDisposable
{
    const string Fremd = "LAPTOP";

    readonly string _dir;
    readonly string _dbPfad;
    readonly string _vorlagen;
    readonly string _ablage;
    readonly LetzteSicherungAkte _merker;

    string _eingestellterOrdner;

    public ArbeitsplatzUebergabeTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "uebergabe-" + Guid.NewGuid().ToString("N"));
        _dbPfad = Path.Combine(_dir, "automation.db");
        _vorlagen = Path.Combine(_dir, "Vorlagen");
        _ablage = Path.Combine(_dir, "Ablage");
        Directory.CreateDirectory(_vorlagen);
        Directory.CreateDirectory(_ablage);
        _eingestellterOrdner = _ablage;
        _merker = new LetzteSicherungAkte(Path.Combine(_dir, "letzte-sicherung.json"));
    }

    [Fact]
    public async Task Ein_neuerer_fremder_Stand_wird_angeboten()
    {
        await LegeDatenbankAn(_dbPfad, "Meine Kanzlei");
        await LegeFremdeSicherungAn(gesichertAm: DateTime.Now);

        var angebot = Uebergabe().Stand().Angebot;

        angebot.Should().NotBeNull();
        angebot!.Rechnername.Should().Be(Fremd);
    }

    [Fact]
    public async Task Der_eigene_neuere_Stand_schlaegt_den_fremden()
    {
        await LegeDatenbankAn(_dbPfad, "Meine Kanzlei");
        await LegeFremdeSicherungAn(gesichertAm: DateTime.Now.AddHours(-3));
        ArbeitsplatzAkte.MerkeSicherung(_ablage, DateTime.Now, "automation-hier-jetzt.zip");

        Uebergabe().Stand().Angebot.Should().BeNull();
    }

    /// <summary>
    /// Die Akte kann schon übertragen sein, während das Archiv daneben noch
    /// lädt. Ein Angebot auf eine Datei, die es nicht gibt, wäre eine Frage,
    /// deren Ja ins Leere geht.
    /// </summary>
    [Fact]
    public async Task Ohne_das_genannte_Archiv_gibt_es_kein_Angebot()
    {
        await LegeDatenbankAn(_dbPfad, "Meine Kanzlei");
        var datei = await LegeFremdeSicherungAn(gesichertAm: DateTime.Now);
        File.Delete(Path.Combine(_ablage, datei));

        Uebergabe().Stand().Angebot.Should().BeNull();
    }

    [Fact]
    public async Task Ohne_eingestellten_Ordner_gibt_es_kein_Angebot_aber_die_Auskunft()
    {
        await LegeDatenbankAn(_dbPfad, "Meine Kanzlei");
        await LegeFremdeSicherungAn(gesichertAm: DateTime.Now);
        _merker.MerkeFehler(DateTime.Now, "Ordner nicht erreichbar");
        _eingestellterOrdner = string.Empty;

        var stand = Uebergabe().Stand();

        stand.Angebot.Should().BeNull();
        stand.AblageOrdner.Should().BeEmpty();
        stand.LetzterLauf!.OffenerFehler.Should().BeTrue();
    }

    /// <summary>
    /// Der Fall, für den das Ganze gebaut ist: Die App wird am zweiten Rechner
    /// zum ersten Mal geöffnet. Danach trägt sie den übernommenen Stand — sonst
    /// böte jeder weitere Start dasselbe Archiv erneut an.
    /// </summary>
    [Fact]
    public async Task Uebernehmen_holt_den_fremden_Bestand_und_fragt_danach_nicht_erneut()
    {
        await LegeDatenbankAn(_dbPfad, "Meine Kanzlei");
        await SchreibeAblageOrdnerInDieEigeneDatenbank();
        await LegeFremdeSicherungAn(gesichertAm: DateTime.Now);
        var uebergabe = Uebergabe();

        var ergebnis = await uebergabe.UebernehmenAsync();

        ergebnis.Rechnername.Should().Be(Fremd);
        var settings = await LiesEinstellungen();
        settings.Name.Should().Be("Kanzlei am Laptop");
        settings.SicherungsAblageOrdner.Should().Be(_ablage,
            "der Ablageordner ist maschinenabhaengig und darf den Import nicht mitmachen");
        uebergabe.Stand().Angebot.Should().BeNull("der Stand ist jetzt der eigene");
    }

    [Fact]
    public async Task Uebernehmen_ohne_Angebot_meldet_das_und_ruehrt_nichts_an()
    {
        await LegeDatenbankAn(_dbPfad, "Meine Kanzlei");

        var ergebnis = await Uebergabe().UebernehmenAsync();

        ergebnis.Rechnername.Should().BeNull();
        (await LiesEinstellungen()).Name.Should().Be("Meine Kanzlei");
    }

    ArbeitsplatzUebergabe Uebergabe() => new(
        new DatabaseBackupService(
            _dbPfad, () => _vorlagen, NullLogger<DatabaseBackupService>.Instance),
        _merker,
        () => _eingestellterOrdner,
        NullLogger<ArbeitsplatzUebergabe>.Instance);

    /// <summary>
    /// Baut eine echte Sicherung aus einer zweiten Datenbank und legt sie samt
    /// Akte so ab, wie es der andere Arbeitsplatz täte.
    /// </summary>
    async Task<string> LegeFremdeSicherungAn(DateTime gesichertAm)
    {
        var fremdeDb = Path.Combine(_dir, "fremd.db");
        await LegeDatenbankAn(fremdeDb, "Kanzlei am Laptop");
        var gebaut = await new DatabaseBackupService(
                fremdeDb, () => _vorlagen, NullLogger<DatabaseBackupService>.Instance)
            .CreateBackupFileAsync();

        var datei = $"automation-{Fremd}-{gesichertAm:yyyyMMdd-HHmmss}.zip";
        File.Move(gebaut, Path.Combine(_ablage, datei), overwrite: true);
        ArbeitsplatzAkte.Schreibe(_ablage, new ArbeitsplatzEintrag(
            Fremd, gesichertAm, gesichertAm, datei, "1.4.2"));
        SqliteConnection.ClearAllPools();
        return datei;
    }

    async Task SchreibeAblageOrdnerInDieEigeneDatenbank()
    {
        await using (var db = Kontext(_dbPfad))
        {
            var settings = await db.KanzleiSettings.SingleAsync();
            settings.SicherungsAblageOrdner = _ablage;
            await db.SaveChangesAsync();
        }

        SqliteConnection.ClearAllPools();
    }

    async Task<KanzleiSettingsEntity> LiesEinstellungen()
    {
        await using var db = Kontext(_dbPfad);
        return await db.KanzleiSettings.AsNoTracking().SingleAsync();
    }

    async Task LegeDatenbankAn(string pfad, string kanzleiname)
    {
        Directory.CreateDirectory(_dir);
        await using (var db = Kontext(pfad))
        {
            await db.Database.MigrateAsync();
            var settings = KanzleiSettingsRepository.CreateDefault();
            settings.Name = kanzleiname;
            db.KanzleiSettings.Add(settings);
            await db.SaveChangesAsync();
        }

        SqliteConnection.ClearAllPools();
    }

    static AutomationDbContext Kontext(string pfad) => new(
        new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={pfad}")
            .Options);

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
