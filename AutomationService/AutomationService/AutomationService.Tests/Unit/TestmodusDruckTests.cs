using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Druck im E2E-Testmodus (#168): kein Papier, aber eine Kopie der Datei, die
/// Word gedruckt hätte, und als Drucker „Testmodus (kein Druck)".
///
/// Der Fall, auf den es ankommt, ist der über <see cref="VollmachtDienst"/>:
/// Er löscht die Arbeitsdatei unmittelbar nach dem Druck. Eine Attrappe, die
/// erst danach kopierte, hinterließe nichts — und fiele erst im Testlauf auf.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class TestmodusDruckTests : IDisposable
{
    private readonly TestmodusUmgebung _umgebung = new();
    private readonly WordVorlagenUmgebung _word = new();
    private readonly string _vorlagenOrdner =
        Path.Combine(Path.GetTempPath(), $"VollmachtVorlagen_{Guid.NewGuid():N}");

    public void Dispose()
    {
        _umgebung.Dispose();
        _word.Dispose();
        if (Directory.Exists(_vorlagenOrdner))
        {
            Directory.Delete(_vorlagenOrdner, true);
        }
    }

    private TestmodusWordDrucker Drucker() => new(_umgebung.Ordner, _umgebung.Protokoll);

    [Fact]
    public async Task Die_Kopie_bleibt_auch_wenn_die_Quelle_danach_geloescht_wird()
    {
        var quelle = _umgebung.Eingabedatei("Vollmacht Unfallsachen.docx", "der Inhalt, den Word gedruckt hätte");

        var drucker = await Drucker().DruckeAsync(quelle);
        File.Delete(quelle);

        drucker.Should().Be("Testmodus (kein Druck)");
        var zeile = _umgebung.Zeilen().Should().ContainSingle().Subject;
        zeile.Aktion.Should().Be("druck");
        zeile.Referenz.Should().BeNull();
        zeile.Datei.Should().StartWith("Druck/").And.EndWith("_Vollmacht Unfallsachen.docx");
        (await File.ReadAllTextAsync(_umgebung.VollerPfad(zeile.Datei!)))
            .Should().Be("der Inhalt, den Word gedruckt hätte");
    }

    [Fact]
    public async Task Ueber_den_VollmachtDienst_ist_die_Arbeitsdatei_weg_und_die_Kopie_da()
    {
        new VollmachtVorlagenOrdner(_vorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance)
            .Ergaenze(VollmachtDienstTests.MusterOrdner());
        var dienst = new VollmachtDienst(
            _word.CreateService(),
            Drucker(),
            new PdfAttrappe(),
            new VollmachtVorlagenOrdner(_vorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance),
            _word.ArbeitsVerzeichnis,
            NullLogger<VollmachtDienst>.Instance);
        var auftrag = VollmachtDienstTests.Auftrag(VollmachtArt.Unfallsachen);

        var ergebnis = await dienst.DruckeAsync(auftrag);

        ergebnis.Art.Should().Be(VollmachtErgebnisArt.Gedruckt);
        ergebnis.Drucker.Should().Be(TestmodusWordDrucker.Druckername, "der Dialog sagt, dass nichts gedruckt wurde");
        var arbeitsordner = Path.Combine(
            _word.ArbeitsVerzeichnis.Wurzel, ArbeitsVerzeichnis.Ordnername(auftrag.Referenz));
        (Directory.Exists(arbeitsordner) ? Directory.GetFiles(arbeitsordner) : [])
            .Should().BeEmpty("nach dem Druck räumt der Dienst die Arbeitsdatei ab");

        var zeile = _umgebung.Zeilen().Should().ContainSingle().Subject;
        using var kopie = DocX.Load(_umgebung.VollerPfad(zeile.Datei!));
        kopie.Text.Should().Contain("Anna Mustermann", "kopiert ist die ausgefüllte Vollmacht, nicht die Vorlage")
            .And.NotContain("{{");
    }

    [Fact]
    public void Die_Auskunft_nennt_vor_dem_Druck_denselben_Drucker()
    {
        new TestmodusDruckerAuskunft().Standarddrucker()
            .Should().Be(new DruckerLage("Testmodus (kein Druck)", DruckerZustand.Bereit));
    }
}
