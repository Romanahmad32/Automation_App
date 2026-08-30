using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft den Register-Spiegel als Ganzes (§6.2, #40) gegen eine echte
/// In-Memory-SQLite und einen echten Ordner: Wann geschrieben wird, wann nicht,
/// und was im Ablageordner passiert, wenn etwas schiefgeht.
///
/// Alles, was an der PDF-Fassung hängt, steht in
/// <see cref="RegisterSpiegelPdfTests"/> — die beiden Dateien teilen sich
/// <see cref="RegisterSpiegelUmgebung"/>.
/// </summary>
public sealed class RegisterSpiegelServiceTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    RegisterSpiegelService Dienst() => _umgebung.Dienst();

    Task EinstellungenAnlegen(string? ordner = null, string filter = "alle") =>
        _umgebung.EinstellungenAnlegen(ordner, filter);

    Task VorgangAnlegen(string referenz, int nummer, string status = "versendet") =>
        _umgebung.VorgangAnlegen(referenz, nummer, status);

    string Docx => _umgebung.DocxPfad;

    string Pdf => _umgebung.PdfPfad;

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
        Directory.EnumerateFiles(_umgebung.Ablage).Should().BeEmpty();
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
        _umgebung.Pdf.Aufrufe.Should().Be(1, "auch die teure Wandlung entfällt");
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

    [Fact]
    public async Task Schreibe_LaesstDasGewachseneKanzleidokumentDanebenUnangetastet()
    {
        var kanzleidatei = Path.Combine(_umgebung.Ablage, "Sachgebiete_laufende Nummern_ab 2018.docx");
        await File.WriteAllTextAsync(kanzleidatei, "die Handarbeit von sieben Jahren");
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);

        await Dienst().SchreibeAsync();

        (await File.ReadAllTextAsync(kanzleidatei)).Should().Be("die Handarbeit von sieben Jahren");
    }

    /// <summary>
    /// Der Fall, in dem der Anwalt den Dateinamen auf den seines gewachsenen
    /// Dokuments stellt — „die Datei soll heißen wie immer". Ohne diese
    /// Prüfung waeren die 93 Seiten Handarbeit beim nächsten Abschluss
    /// ersetzt, ungefragt und ohne Sicherung.
    /// </summary>
    [Fact]
    public async Task Schreibe_LaesstEineFremdeDateiAmZielortUnangetastet()
    {
        await File.WriteAllTextAsync(Docx, "die Handarbeit von sieben Jahren");
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Geschrieben.Should().BeFalse();
        ergebnis.Fehler.Should().Contain("nicht von der App");
        (await File.ReadAllTextAsync(Docx)).Should().Be("die Handarbeit von sieben Jahren");
        File.Exists(Pdf).Should().BeFalse("auch das PDF darf dann nicht entstehen");
    }

    /// <summary>
    /// Die Kehrseite: Was der Spiegel selbst geschrieben hat, ersetzt er beim
    /// nächsten Lauf weiterhin — sonst schriebe er genau einmal.
    /// </summary>
    [Fact]
    public async Task Schreibe_ErsetztDieEigeneFassungWeiterhin()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();

        await VorgangAnlegen("02/26 C03", 2);
        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeTrue();
        zweiter.Fehler.Should().BeNull();
    }

    [Fact]
    public async Task Schreibe_LaesstKeineZwischenstaendeImAblageordner()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);

        await Dienst().SchreibeAsync();

        Directory.EnumerateFiles(_umgebung.Ablage).Select(Path.GetFileName)
            .Should().BeEquivalentTo([$"{RegisterSpiegelVorgabe.Dateiname}.docx",
                $"{RegisterSpiegelVorgabe.Dateiname}.pdf"]);
    }

    [Fact]
    public async Task Schreibe_MeldetEineKonfliktkopieNebenDemSpiegel()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await File.WriteAllTextAsync(
            Path.Combine(_umgebung.Ablage, $"{RegisterSpiegelVorgabe.Dateiname}-LAPTOP-ANWALT.docx"),
            "unterwegs");

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Konfliktkopien.Should().ContainSingle()
            .Which.Should().Contain("LAPTOP-ANWALT");
    }

    /// <summary>
    /// Die Warnung darf nicht daran hängen, dass gerade geschrieben wurde: Ein
    /// übersprungener Lauf ist der Normalfall, und die Konfliktkopie daneben
    /// verschwindet dadurch nicht.
    /// </summary>
    [Fact]
    public async Task Schreibe_MeldetDieKonfliktkopieAuchBeiUnveraendertemBestand()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();
        await File.WriteAllTextAsync(
            Path.Combine(_umgebung.Ablage, $"{RegisterSpiegelVorgabe.Dateiname}-LAPTOP-ANWALT.docx"),
            "unterwegs");

        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeFalse("der Bestand hat sich nicht geändert");
        zweiter.Konfliktkopien.Should().ContainSingle()
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

    public void Dispose() => _umgebung.Dispose();
}
