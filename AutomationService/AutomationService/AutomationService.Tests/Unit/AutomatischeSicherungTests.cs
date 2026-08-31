using System.IO.Compression;
using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die automatische Sicherung in den synchronisierten Ordner (#39) — der
/// Schritt, der aus „ich könnte sichern" ein „der Stand ist drüben" macht.
///
/// Geprüft wird gegen eine echte Datenbank und ein echtes Archiv: Eine
/// Sicherung, die entsteht, aber nicht lesbar ist, wäre die schlechteste aller
/// Antworten — sie fällt erst auf, wenn jemand sie braucht.
/// </summary>
public sealed class AutomatischeSicherungTests : IDisposable
{
    readonly string _dir;
    readonly string _dbPfad;
    readonly string _vorlagen;
    readonly string _ablage;
    readonly LetzteSicherungAkte _merker;

    string _eingestellterOrdner;

    public AutomatischeSicherungTests()
    {
        _dir = Path.Combine(Path.GetTempPath(), "autosicherung-" + Guid.NewGuid().ToString("N"));
        _dbPfad = Path.Combine(_dir, "automation.db");
        _vorlagen = Path.Combine(_dir, "Vorlagen");
        _ablage = Path.Combine(_dir, "OneDrive", "Kanzlei-Sicherungen");
        Directory.CreateDirectory(_vorlagen);
        _eingestellterOrdner = _ablage;
        _merker = new LetzteSicherungAkte(Path.Combine(_dir, "letzte-sicherung.json"));
    }

    [Fact]
    public async Task Der_Stand_landet_als_lesbares_Archiv_im_Ablageordner()
    {
        await LegeDatenbankAn();
        await File.WriteAllTextAsync(Path.Combine(_vorlagen, "Anspruch.docx"), "Vorlage");

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Should().NotBeNull();
        ergebnis!.Gelungen.Should().BeTrue();
        var archiv = Path.Combine(_ablage, ergebnis.Datei!);
        File.Exists(archiv).Should().BeTrue();
        using var zip = ZipFile.OpenRead(archiv);
        zip.GetEntry(SicherungsArchiv.DatenbankEintrag).Should().NotBeNull();
        zip.GetEntry($"{SicherungsArchiv.VorlagenOrdner}/Anspruch.docx").Should().NotBeNull();
    }

    /// <summary>
    /// Das Archiv trägt den Rechnernamen, und die Akte daneben sagt, zu welchem
    /// Zeitpunkt er gehört — daran entscheidet der andere Arbeitsplatz sein
    /// Übernahme-Angebot.
    /// </summary>
    [Fact]
    public async Task Die_Arbeitsplatz_Akte_zeigt_danach_auf_dieses_Archiv()
    {
        await LegeDatenbankAn();

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis!.Datei.Should().Contain(ArbeitsplatzAkte.DieserRechner);
        var eintrag = ArbeitsplatzAkte.LiesEigene(_ablage);
        eintrag.Should().NotBeNull();
        eintrag!.Sicherung.Should().Be(ergebnis.Datei);
        eintrag.GesichertAm.Should().NotBeNull();
    }

    [Fact]
    public async Task Ohne_eingestellten_Ablageordner_passiert_nichts()
    {
        await LegeDatenbankAn();
        _eingestellterOrdner = string.Empty;

        (await Dienst().SchreibeAsync()).Should().BeNull();

        Directory.Exists(_ablage).Should().BeFalse();
        _merker.Lies().Should().BeNull("ein abgeschalteter Dienst hat nichts zu melden");
    }

    /// <summary>
    /// Beide Arbeitsplätze legen in denselben Ordner. Räumte einer nach Alter
    /// auf, nähme er dem anderen genau das weg, was dieser zur Übergabe braucht.
    /// </summary>
    [Fact]
    public async Task Aufgeraeumt_werden_nur_die_eigenen_Sicherungen()
    {
        await LegeDatenbankAn();
        Directory.CreateDirectory(_ablage);
        var fremd = Path.Combine(_ablage, "automation-LAPTOP-20260101-120000.zip");
        await File.WriteAllTextAsync(fremd, "gehoert dem anderen Rechner");
        for (var i = 0; i < AutomatischeSicherung.AufbewahrteSicherungen + 1; i++)
        {
            var alt = Path.Combine(
                _ablage, $"automation-{ArbeitsplatzAkte.DieserRechner}-2026010{i % 10}-1200{i:00}.zip");
            await File.WriteAllTextAsync(alt, "alt");
            File.SetCreationTimeUtc(alt, new DateTime(2026, 1, 1, 0, i, 0, DateTimeKind.Utc));
        }

        await Dienst().SchreibeAsync();

        File.Exists(fremd).Should().BeTrue("fremde Staende gehen diesen Rechner nichts an");
        Directory.GetFiles(_ablage, AutomatischeSicherung.SuchmusterFuer(ArbeitsplatzAkte.DieserRechner))
            .Should().HaveCount(AutomatischeSicherung.AufbewahrteSicherungen);
    }

    /// <summary>
    /// Der Lauf passiert, wenn das Fenster schon zu ist. Er darf nichts werfen —
    /// und muss den Fehlschlag so hinterlassen, dass ihn der nächste Start
    /// zeigen kann.
    /// </summary>
    [Fact]
    public async Task Ein_unerreichbarer_Ablageordner_wirft_nicht_und_wird_gemerkt()
    {
        await LegeDatenbankAn();
        // Eine Datei da, wo der Ordner sein soll: praktisch dasselbe wie ein
        // umbenannter oder getrennter OneDrive-Pfad.
        var blockiert = Path.Combine(_dir, "keinOrdner");
        await File.WriteAllTextAsync(blockiert, "ich bin eine Datei");
        _eingestellterOrdner = Path.Combine(blockiert, "Sicherungen");

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Should().NotBeNull();
        ergebnis!.Gelungen.Should().BeFalse();
        ergebnis.OffenerFehler.Should().BeTrue();
        _merker.Lies()!.Meldung.Should().Contain(_eingestellterOrdner);
    }

    [Fact]
    public async Task Eine_quittierte_Meldung_kommt_nicht_wieder()
    {
        await LegeDatenbankAn();
        _eingestellterOrdner = Path.Combine(_dir, "automation.db", "Sicherungen");

        await Dienst().SchreibeAsync();
        _merker.Quittiere();

        _merker.Lies()!.OffenerFehler.Should().BeFalse();
        _merker.Lies()!.Meldung.Should().NotBeNull("die Ursache bleibt lesbar");
    }

    AutomatischeSicherung Dienst() => new(
        new DatabaseBackupService(
            _dbPfad, () => _vorlagen, NullLogger<DatabaseBackupService>.Instance),
        _merker,
        () => _eingestellterOrdner,
        NullLogger<AutomatischeSicherung>.Instance);

    async Task LegeDatenbankAn()
    {
        Directory.CreateDirectory(_dir);
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite($"Data Source={_dbPfad}")
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
