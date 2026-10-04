using System.Text;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Seitenvorschau der Vollmacht (§4.11, #164). Sie zeigt, was gedruckt
/// würde — und hinterlässt nichts: Die Vollmacht wird nicht digital
/// aufbewahrt, weder als ausgefüllte .docx im Arbeitsordner noch als PDF im
/// Vorschau-Cache.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class VollmachtVorschauTests : IDisposable
{
    private readonly WordVorlagenUmgebung _umgebung = new();
    private readonly string _vorlagenOrdner =
        Path.Combine(Path.GetTempPath(), $"VollmachtVorschau_{Guid.NewGuid():N}");
    private readonly PdfSpion _pdf = new();

    private VollmachtVorlagenOrdner Ordner() =>
        new(_vorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance);

    private VollmachtDienst Dienst() => new(
        _umgebung.CreateService(),
        new KeinDrucker(),
        _pdf,
        Ordner(),
        NullLogger<VollmachtDienst>.Instance);

    [Fact]
    public async Task Die_Vorschau_liefert_die_Seite_und_laesst_keine_Datei_liegen()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        var auftrag = VollmachtDienstTests.Auftrag(VollmachtArt.Unfallsachen);

        var vorschau = await Dienst().VorschauAsync(auftrag);

        vorschau.Art.Should().Be(VollmachtVorschauArt.Erstellt);
        Encoding.UTF8.GetString(vorschau.Pdf!).Should().Be(PdfSpion.Seite);
        vorschau.Warnungen.Should().BeEmpty();
        var arbeitsordner = _umgebung.ArbeitsVerzeichnis.OrdnerFuer(auftrag.Referenz);
        (Directory.Exists(arbeitsordner) ? Directory.GetFiles(arbeitsordner) : [])
            .Should().BeEmpty("die ausgefüllte Vollmacht bleibt nicht liegen");
    }

    /// <summary>
    /// Der Pfad-Weg der Umwandlung legt jede PDF im Vorschau-Cache ab
    /// (<c>Generated/PdfCache</c>). Nähme die Vorschau ihn, läge dort jede
    /// je gezeigte Vollmacht samt Mandantendaten.
    /// </summary>
    [Fact]
    public async Task Die_Vorschau_geht_am_PDF_Cache_vorbei()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());

        await Dienst().VorschauAsync(VollmachtDienstTests.Auftrag(VollmachtArt.Strafsache));

        _pdf.UeberPfad.Should().BeEmpty();
        _pdf.UeberBytes.Should().Be(1);
    }

    /// <summary>
    /// Vorschau und Druck schreiben in denselben Arbeitsordner. Hieße die
    /// Vorschaudatei wie die Druckdatei, löschte „Aktualisieren" kurz vor
    /// „Drucken" die Datei, die gerade gedruckt werden soll.
    /// </summary>
    [Fact]
    public async Task Die_Vorschau_laesst_eine_Druckdatei_daneben_liegen()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        var auftrag = VollmachtDienstTests.Auftrag(VollmachtArt.Unfallsachen);
        var zumDruck = Dienst().FuelleAus(auftrag).Pfad!;

        await Dienst().VorschauAsync(auftrag);

        File.Exists(zumDruck).Should().BeTrue();
    }

    [Fact]
    public async Task Fehlt_die_Vorlage_sagt_die_Vorschau_welche()
    {
        var vorschau = await Dienst().VorschauAsync(VollmachtDienstTests.Auftrag(VollmachtArt.Bussgeldsachen));

        vorschau.Art.Should().Be(VollmachtVorschauArt.VorlageFehlt);
        vorschau.Meldung.Should().Contain("Vollmacht Bussgeldsachen.docx");
        vorschau.Pdf.Should().BeNull();
    }

    [Fact]
    public async Task Scheitert_die_Umwandlung_bleibt_ein_Hinweis_und_keine_Datei()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        _pdf.Wirft = new PdfConversionUnavailableException("Word fehlt.");
        var auftrag = VollmachtDienstTests.Auftrag(VollmachtArt.Unfallsachen);

        var vorschau = await Dienst().VorschauAsync(auftrag);

        vorschau.Art.Should().Be(VollmachtVorschauArt.Fehler);
        vorschau.Meldung.Should().Contain("drucken können Sie trotzdem");
        var arbeitsordner = _umgebung.ArbeitsVerzeichnis.OrdnerFuer(auftrag.Referenz);
        (Directory.Exists(arbeitsordner) ? Directory.GetFiles(arbeitsordner) : []).Should().BeEmpty();
    }

    public void Dispose()
    {
        _umgebung.Dispose();
        if (Directory.Exists(_vorlagenOrdner))
        {
            Directory.Delete(_vorlagenOrdner, true);
        }
    }

    /// <summary>Zählt, über welchen Weg umgewandelt wurde.</summary>
    private sealed class PdfSpion : IPdfConversionService
    {
        public const string Seite = "%PDF-Vollmacht";

        public List<string> UeberPfad { get; } = [];

        public int UeberBytes { get; private set; }

        public Exception? Wirft { get; set; }

        public Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath)
        {
            UeberPfad.Add(docxFilePath);
            return Task.FromResult(Encoding.UTF8.GetBytes(Seite));
        }

        public Task<byte[]> ConvertDocxToPdfFromBytesAsync(byte[] docxBytes)
        {
            UeberBytes++;
            if (Wirft is not null)
            {
                throw Wirft;
            }

            docxBytes.Should().NotBeEmpty("umgewandelt wird die ausgefüllte Datei");
            return Task.FromResult(Encoding.UTF8.GetBytes(Seite));
        }
    }

    private sealed class KeinDrucker : IWordDrucker
    {
        public Task<string?> DruckeAsync(string docxPfad, CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("Die Vorschau druckt nicht.");
    }
}
