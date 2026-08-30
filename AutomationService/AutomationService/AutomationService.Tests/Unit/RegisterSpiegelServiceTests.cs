using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft den Register-Spiegel als Ganzes (§6.2, #40) gegen eine echte
/// In-Memory-SQLite und einen echten Ordner: Wann geschrieben wird, wann nicht,
/// und was im Ablageordner passiert, wenn etwas schiefgeht.
/// </summary>
public sealed class RegisterSpiegelServiceTests : IDisposable
{
    readonly SqliteConnection _verbindung;
    readonly AutomationDbContext _db;
    readonly string _ablage = Directory.CreateTempSubdirectory("register-ablage").FullName;
    readonly string _bau = Directory.CreateTempSubdirectory("register-bau").FullName;
    readonly string _standDatei;
    readonly PdfAttrappe _pdf = new();

    public RegisterSpiegelServiceTests()
    {
        _verbindung = new SqliteConnection("DataSource=:memory:");
        _verbindung.Open();
        _db = new AutomationDbContext(new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_verbindung).Options);
        _db.Database.EnsureCreated();
        _standDatei = Path.Combine(_bau, "stand.json");
    }

    RegisterSpiegelService Dienst() => new(
        _db,
        _pdf,
        new RegisterSpiegelStand(_standDatei),
        new RegisterSpiegelBauordner(_bau),
        NullLogger<RegisterSpiegelService>.Instance);

    async Task EinstellungenAnlegen(string? ordner = null, string filter = "alle")
    {
        var einstellungen = KanzleiSettingsRepository.CreateDefault();
        einstellungen.RegisterAblageOrdner = ordner ?? _ablage;
        einstellungen.RegisterExportFilter = filter;
        _db.KanzleiSettings.Add(einstellungen);
        await _db.SaveChangesAsync();
    }

    async Task VorgangAnlegen(string referenz, int nummer, string status = "versendet")
    {
        _db.Vorgaenge.Add(new VorgangEntity
        {
            Referenz = referenz,
            Status = status,
            Rechtsgebiet = "verkehrsrecht",
            LaufendeNummer = nummer,
            Jahr = "26",
            Abteilung = "C03",
            MandantName = "Mustermann",
            Gegner = "HUK",
            AngefragtAm = new DateTime(2026, 1, 5),
        });
        await _db.SaveChangesAsync();
    }

    string Docx => Path.Combine(_ablage, $"{RegisterSpiegelVorgabe.Dateiname}.docx");
    string Pdf => Path.Combine(_ablage, $"{RegisterSpiegelVorgabe.Dateiname}.pdf");

    [Fact]
    public async Task Schreibe_LegtWordUndPdfImAblageordnerAn()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Geschrieben.Should().BeTrue();
        ergebnis.Zeilen.Should().Be(1);
        File.Exists(Docx).Should().BeTrue();
        File.Exists(Pdf).Should().BeTrue();
    }

    [Fact]
    public async Task Schreibe_TutNichts_OhneEingestelltenAblageordner()
    {
        await EinstellungenAnlegen(ordner: string.Empty);
        await VorgangAnlegen("01/26 C03", 1);

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Geschrieben.Should().BeFalse();
        ergebnis.Grund.Should().Contain("kein Ablageordner");
        Directory.EnumerateFiles(_ablage).Should().BeEmpty();
    }

    /// <summary>
    /// Der Grund, warum der Spiegel nicht dasselbe Schicksal nimmt wie das
    /// abgelöste Dokument bei Revision 5341: Ohne Änderung wird nicht
    /// geschrieben, und der Versionsverlauf in der Cloud bleibt lesbar.
    /// </summary>
    [Fact]
    public async Task Schreibe_SchreibtNichtZweimalDenselbenBestand()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();
        var ersterStand = File.GetLastWriteTimeUtc(Docx);

        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeFalse();
        zweiter.Grund.Should().Contain("nicht geändert");
        File.GetLastWriteTimeUtc(Docx).Should().Be(ersterStand);
        _pdf.Aufrufe.Should().Be(1, "auch die teure Wandlung entfällt");
    }

    [Fact]
    public async Task Schreibe_SchreibtWieder_WennEinVorgangDazukommt()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();

        await VorgangAnlegen("02/26 C03", 2);
        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeTrue();
        zweiter.Zeilen.Should().Be(2);
    }

    [Fact]
    public async Task Schreibe_HoltEineVonHandGeloeschteDateiZurueck()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();
        AtomareAblage.SchreibschutzLoesen(Docx);
        File.Delete(Docx);

        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeTrue();
        File.Exists(Docx).Should().BeTrue();
    }

    [Fact]
    public async Task Schreibe_NimmtMitFilterNurAbgeschlosseneAuf()
    {
        await EinstellungenAnlegen(filter: RegisterSpiegelVorgabe.FilterAbgeschlossen);
        await VorgangAnlegen("01/26 C03", 1);
        await VorgangAnlegen("02/26 C03", 2, status: "angefragt");

        (await Dienst().SchreibeAsync()).Zeilen.Should().Be(1);
    }

    [Fact]
    public async Task Schreibe_MeldetDasGesperrteZielUndLaesstDieAlteFassungStehen()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();
        var alteGroesse = new FileInfo(Docx).Length;

        await VorgangAnlegen("02/26 C03", 2);
        AtomareAblage.SchreibschutzLoesen(Docx);
        using (new FileStream(Docx, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            var ergebnis = await Dienst().SchreibeAsync();

            ergebnis.Geschrieben.Should().BeFalse();
            ergebnis.Fehler.Should().Contain("geöffnet");
        }

        new FileInfo(Docx).Length.Should().Be(alteGroesse);
    }

    /// <summary>
    /// Ohne installiertes Word gibt es kein PDF — die .docx ist trotzdem die
    /// verbindliche Fassung und muss geschrieben werden.
    /// </summary>
    [Fact]
    public async Task Schreibe_LegtDieWordDateiAn_AuchWennDieWandlungScheitert()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        _pdf.Wirft = new InvalidOperationException("Word ist nicht verfügbar.");

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Geschrieben.Should().BeTrue();
        ergebnis.PdfFehler.Should().Contain("Word ist nicht verfügbar");
        File.Exists(Docx).Should().BeTrue();
        File.Exists(Pdf).Should().BeFalse();
    }

    [Fact]
    public async Task Schreibe_LaesstDasGewachseneKanzleidokumentDanebenUnangetastet()
    {
        var kanzleidatei = Path.Combine(_ablage, "Sachgebiete_laufende Nummern_ab 2018.docx");
        await File.WriteAllTextAsync(kanzleidatei, "die Handarbeit von sieben Jahren");
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);

        await Dienst().SchreibeAsync();

        (await File.ReadAllTextAsync(kanzleidatei)).Should().Be("die Handarbeit von sieben Jahren");
    }

    [Fact]
    public async Task Schreibe_LaesstKeineZwischenstaendeImAblageordner()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);

        await Dienst().SchreibeAsync();

        Directory.EnumerateFiles(_ablage).Select(Path.GetFileName)
            .Should().BeEquivalentTo([$"{RegisterSpiegelVorgabe.Dateiname}.docx",
                $"{RegisterSpiegelVorgabe.Dateiname}.pdf"]);
    }

    [Fact]
    public async Task Schreibe_MeldetEineKonfliktkopieNebenDemSpiegel()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await File.WriteAllTextAsync(
            Path.Combine(_ablage, $"{RegisterSpiegelVorgabe.Dateiname}-LAPTOP-ANWALT.docx"), "unterwegs");

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Konfliktkopien.Should().ContainSingle()
            .Which.Should().Contain("LAPTOP-ANWALT");
    }

    [Fact]
    public async Task Stand_MeldetDenLetztenLaufOhneSelbstZuSchreiben()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();
        var geschriebenAm = File.GetLastWriteTimeUtc(Docx);

        var stand = await Dienst().StandAsync();

        stand.Geschrieben.Should().BeFalse();
        stand.DocxPfad.Should().Be(Docx);
        stand.GeschriebenAm.Should().NotBeNull();
        File.GetLastWriteTimeUtc(Docx).Should().Be(geschriebenAm);
    }

    public void Dispose()
    {
        _db.Dispose();
        _verbindung.Dispose();
        foreach (var datei in Directory.EnumerateFiles(_ablage)) AtomareAblage.SchreibschutzLoesen(datei);
        Directory.Delete(_ablage, recursive: true);
        Directory.Delete(_bau, recursive: true);
    }
}
