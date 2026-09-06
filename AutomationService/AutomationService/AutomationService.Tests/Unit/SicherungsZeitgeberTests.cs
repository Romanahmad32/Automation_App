using System.IO.Compression;
using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Backup.Presentation.HostedServices;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die zeitgesteuerte Sicherung während der Arbeit (#112).
///
/// Geprüft wird über <c>TickAsync</c> statt über den Zeitablauf: Ein Test, der
/// auf den Takt wartet, prüft die Uhr und nicht die Regel. Gesichert wird gegen
/// eine echte Datenbank und echte Archive — eine Sicherung, die entsteht, aber
/// nicht lesbar ist, fällt sonst erst auf, wenn jemand sie braucht.
/// </summary>
public sealed class SicherungsZeitgeberTests : IDisposable
{
    readonly string _dir;
    readonly string _dbPfad;
    readonly string _vorlagen;
    readonly string _ablage;
    readonly LetzteSicherungAkte _merker;

    string _eingestellterOrdner;

    public SicherungsZeitgeberTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "zeitgeber-" + Guid.NewGuid().ToString("N"));
        _dbPfad = Path.Combine(_dir, "automation.db");
        _vorlagen = Path.Combine(_dir, "Vorlagen");
        _ablage = Path.Combine(_dir, "OneDrive", "Kanzlei-Sicherungen");
        Directory.CreateDirectory(_vorlagen);
        _eingestellterOrdner = _ablage;
        _merker = new LetzteSicherungAkte(Path.Combine(_dir, "letzte-sicherung.json"));
    }

    /// <summary>
    /// Ohne diese Prüfung entstünden an einem Tag ohne Eingaben ein Dutzend
    /// gleicher Archive — und verdrängten genau die Historie, für die sie da sind.
    /// </summary>
    [Fact]
    public async Task Ohne_Aenderung_entsteht_kein_zweites_Archiv()
    {
        await LegeDatenbankAn();
        var zeitgeber = Zeitgeber();

        (await zeitgeber.TickAsync()).Should().BeTrue("beim ersten Takt ist kein Stand bekannt");
        (await zeitgeber.TickAsync()).Should().BeFalse("seither hat niemand etwas geschrieben");

        EigeneArchive().Should().ContainSingle();
    }

    [Fact]
    public async Task Nach_einer_Aenderung_entsteht_genau_ein_weiteres_Archiv()
    {
        await LegeDatenbankAn();
        var zeitgeber = Zeitgeber();
        await zeitgeber.TickAsync();
        DatiereDasErsteArchivZurueck();

        await SchreibeInDieDatenbank();

        (await zeitgeber.TickAsync()).Should().BeTrue("die Datenbankdatei hat sich geändert");
        (await zeitgeber.TickAsync()).Should().BeFalse("und seither wieder nicht");
        EigeneArchive().Should().HaveCount(2);
    }

    /// <summary>
    /// §1.3, kein stilles Scheitern: Der Fehlschlag steht in der Akte und geht
    /// beim nächsten Start auf den Bildschirm. Der Takt läuft trotzdem weiter —
    /// ein Dienst, der nach dem ersten unerreichbaren Ordner schweigt, ist
    /// schlimmer als keiner.
    /// </summary>
    [Fact]
    public async Task Ein_Fehlschlag_landet_in_der_Akte_und_der_Takt_laeuft_weiter()
    {
        await LegeDatenbankAn();
        // Eine Datei da, wo der Ordner sein soll: praktisch dasselbe wie ein
        // umbenannter oder getrennter OneDrive-Pfad.
        var blockiert = Path.Combine(_dir, "keinOrdner");
        await File.WriteAllTextAsync(blockiert, "ich bin eine Datei");
        _eingestellterOrdner = Path.Combine(blockiert, "Sicherungen");
        var zeitgeber = Zeitgeber();

        (await zeitgeber.TickAsync()).Should().BeFalse();

        _merker.Lies()!.OffenerFehler.Should().BeTrue();
        (await zeitgeber.TickAsync()).Should().BeFalse(
            "der Stand gilt weiter als ungesichert — der nächste Takt versucht es erneut");
        _merker.Lies()!.Gelungen.Should().BeFalse();
    }

    [Fact]
    public async Task Ohne_eingestellten_Ablageordner_passiert_nichts()
    {
        await LegeDatenbankAn();
        _eingestellterOrdner = string.Empty;

        (await Zeitgeber().TickAsync()).Should().BeFalse();

        Directory.Exists(_ablage).Should().BeFalse();
        _merker.Lies().Should().BeNull("ein abgeschalteter Dienst hat nichts zu melden");
    }

    /// <summary>
    /// Der Anwalt schliesst das Fenster, während der Takt gerade sichert. Beide
    /// Läufe müssen zu Ende kommen, und im Ordner darf nichts Halbes liegen —
    /// dafür sorgt die Schleuse in <see cref="AutomatischeSicherung"/>.
    /// </summary>
    [Fact]
    public async Task Zeitgeber_und_Beenden_zugleich_hinterlassen_kein_halbes_Archiv()
    {
        await LegeDatenbankAn();
        var zeitgeber = Zeitgeber();
        var beimBeenden = Dienst();

        var takt = zeitgeber.TickAsync();
        var beenden = beimBeenden.SchreibeAsync();
        await Task.WhenAll(takt, beenden);

        var archive = EigeneArchive();
        archive.Should().NotBeEmpty();
        foreach (var pfad in archive)
        {
            using var zip = ZipFile.OpenRead(pfad);
            zip.GetEntry(SicherungsArchiv.DatenbankEintrag).Should().NotBeNull(
                "jedes abgelegte Archiv ist ein fertiges");
        }
    }

    SicherungsZeitgeber Zeitgeber() => new(
        Dienst(), () => _dbPfad, NullLogger<SicherungsZeitgeber>.Instance);

    AutomatischeSicherung Dienst() => new(
        new DatabaseBackupService(
            _dbPfad, () => _vorlagen, NullLogger<DatabaseBackupService>.Instance),
        _merker,
        () => _eingestellterOrdner,
        NullLogger<AutomatischeSicherung>.Instance);

    string[] EigeneArchive() => Directory.Exists(_ablage)
        ? Directory.GetFiles(
            _ablage, SicherungsDateiname.Suchmuster(ArbeitsplatzAkte.DieserRechner))
        : [];

    /// <summary>
    /// Der Zeitstempel im Namen zählt Sekunden. Zwei Läufe in derselben Sekunde
    /// trügen denselben Namen — der zweite ersetzte den ersten, und der Test
    /// hinge daran, wie schnell die Maschine ist. Deshalb wird das erste Archiv
    /// auf gestern zurückdatiert; die Aufbewahrung lässt beide liegen.
    /// </summary>
    void DatiereDasErsteArchivZurueck()
    {
        var bisher = EigeneArchive().Single();
        File.Move(bisher, Path.Combine(_ablage, SicherungsDateiname.Baue(
            ArbeitsplatzAkte.DieserRechner, DateTime.Now.AddDays(-1))));
    }

    async Task LegeDatenbankAn()
    {
        Directory.CreateDirectory(_dir);
        await using (var db = new AutomationDbContext(Optionen()))
        {
            await db.Database.MigrateAsync();
        }

        SqliteConnection.ClearAllPools();
    }

    /// <summary>Eine echte Eingabe des Anwalts — der Fall, den der Takt sichern soll.</summary>
    async Task SchreibeInDieDatenbank()
    {
        await using (var db = new AutomationDbContext(Optionen()))
        {
            var einstellungen = KanzleiSettingsRepository.CreateDefault();
            einstellungen.Name = "Kanzlei am Vormittag";
            db.KanzleiSettings.Add(einstellungen);
            await db.SaveChangesAsync();
        }

        SqliteConnection.ClearAllPools();
    }

    DbContextOptions<AutomationDbContext> Optionen() =>
        new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_dbPfad}")
            .Options;

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
