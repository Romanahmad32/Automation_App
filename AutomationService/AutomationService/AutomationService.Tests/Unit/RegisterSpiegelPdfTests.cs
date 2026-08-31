using AutomationService.Core.Ablage;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Register-Spiegel und seine PDF-Fassung (§6.2, #40).
///
/// Eigene Datei, weil hier eine eigene Frage geprüft wird: Die .docx ist die
/// verbindliche Fassung, das PDF die bequeme — und beide müssen im
/// Ablageordner immer dasselbe sagen. Ein PDF von gestern neben einer .docx
/// von heute ist der Fall, der einen Spiegel unbemerkt zur Lüge macht, denn
/// unterwegs liest man das PDF.
///
/// Teilt sich <see cref="RegisterSpiegelUmgebung"/> mit
/// <see cref="RegisterSpiegelServiceTests"/>.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RegisterSpiegelPdfTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    RegisterSpiegelService Dienst() => _umgebung.Dienst();

    Task EinstellungenAnlegen() => _umgebung.EinstellungenAnlegen();

    Task VorgangAnlegen(string referenz, int nummer) => _umgebung.VorgangAnlegen(referenz, nummer);

    string Docx => _umgebung.DocxPfad;

    string Pdf => _umgebung.PdfPfad;

    static InvalidOperationException OhneWord() => new("Word ist nicht verfügbar.");

    /// <summary>
    /// Ohne installiertes Word gibt es kein PDF — die .docx ist trotzdem die
    /// verbindliche Fassung und muss geschrieben werden.
    /// </summary>
    [Fact]
    public async Task Schreibe_LegtDieWordDateiAn_AuchWennDieWandlungScheitert()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        _umgebung.Pdf.Wirft = OhneWord();

        var ergebnis = await Dienst().SchreibeAsync();

        ergebnis.Geschrieben.Should().BeTrue();
        ergebnis.PdfFehler.Should().Contain("Word ist nicht verfügbar");
        File.Exists(Docx).Should().BeTrue();
        File.Exists(Pdf).Should().BeFalse();
    }

    /// <summary>
    /// Beim ersten Lauf entstand ein PDF, beim zweiten scheitert die Wandlung.
    /// Bliebe das alte liegen, läse der Anwalt unterwegs ein Register ohne den
    /// neuen Vorgang — und die .docx daneben behauptete das Gegenteil.
    /// </summary>
    [Fact]
    public async Task Schreibe_RaeumtDasVeraltetePdfWeg_WennDieWandlungScheitert()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();
        File.Exists(Pdf).Should().BeTrue("die Ausgangslage ist ein vollständiger Spiegel");

        await VorgangAnlegen("02/26 C03", 2);
        _umgebung.Pdf.Wirft = OhneWord();
        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeTrue();
        zweiter.PdfPfad.Should().BeNull();
        zweiter.PdfFehler.Should().NotBeNull();
        File.Exists(Pdf).Should().BeFalse("ein PDF von gestern ist schlimmer als gar keins");
    }

    /// <summary>
    /// Auf einem Rechner ohne Word entsteht nie ein PDF — „da liegt keins" ist
    /// dort der erwartete Zustand und darf nicht bei jedem Lauf als Änderung
    /// gelten. Sonst käme Revision 5341 durch die Hintertür zurück.
    /// </summary>
    [Fact]
    public async Task Schreibe_SchreibtNichtZweimalDenselbenBestand_AuchOhnePdfFassung()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        _umgebung.Pdf.Wirft = OhneWord();
        await Dienst().SchreibeAsync();
        var ersterStand = File.GetLastWriteTimeUtc(Docx);

        var zweiter = await Dienst().SchreibeAsync();

        zweiter.Geschrieben.Should().BeFalse();
        zweiter.Grund.Should().Contain("nicht geändert");
        File.GetLastWriteTimeUtc(Docx).Should().Be(ersterStand);
    }

    /// <summary>
    /// Das PDF ist offen, die .docx nicht. Die .docx zieht dann um — gemeldet
    /// werden muss genau das, was auf der Platte steht, und nicht „nichts
    /// geschrieben".
    /// </summary>
    [Fact]
    public async Task Schreibe_MeldetDieGeschriebeneWordDatei_WennNurDasPdfGesperrtIst()
    {
        await EinstellungenAnlegen();
        await VorgangAnlegen("01/26 C03", 1);
        await Dienst().SchreibeAsync();

        await VorgangAnlegen("02/26 C03", 2);
        AtomareAblage.SchreibschutzLoesen(Pdf);
        using (new FileStream(Pdf, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            var zweiter = await Dienst().SchreibeAsync();

            zweiter.Geschrieben.Should().BeTrue();
            zweiter.DocxPfad.Should().Be(Docx);
            zweiter.PdfPfad.Should().BeNull();
            zweiter.PdfFehler.Should().NotBeNull();
        }
    }

    public void Dispose() => _umgebung.Dispose();
}
