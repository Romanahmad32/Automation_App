using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Das Aufräumen beim Schließen des Vollmacht-Dialogs (§4.11, §8, #174): Eine
/// in Word geöffnete Fassung bleibt nicht bis zur Startaufräumung liegen. Der
/// Arbeitsordner gehört aber auch dem Anspruchsschreiben — gelöscht werden
/// nur die Vollmachtdateien.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class VollmachtAufraeumenTests : IDisposable
{
    private const string Referenz = "84/26 C03_GG-XY 123";

    private readonly WordVorlagenUmgebung _umgebung = new();
    private readonly string _vorlagenOrdner =
        Path.Combine(Path.GetTempPath(), $"VollmachtAufraeumen_{Guid.NewGuid():N}");

    private VollmachtVorlagenOrdner Ordner() =>
        new(_vorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance);

    private VollmachtDienst Dienst() => new(
        _umgebung.CreateService(),
        new KeinDrucker(),
        new PdfAttrappe(),
        Ordner(),
        _umgebung.ArbeitsVerzeichnis,
        NullLogger<VollmachtDienst>.Instance);

    /// <summary>Der Arbeitsordner, ohne ihn anzulegen.</summary>
    private string Arbeitsordner(string referenz = Referenz) =>
        Path.Combine(_umgebung.ArbeitsVerzeichnis.Wurzel, ArbeitsVerzeichnis.Ordnername(referenz));

    private string FuelleAus(VollmachtArt art) =>
        Dienst().FuelleAus(VollmachtDienstTests.Auftrag(art)).Pfad!;

    [Fact]
    public async Task Ein_Schreiben_im_selben_Arbeitsordner_bleibt_liegen()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        var unfall = FuelleAus(VollmachtArt.Unfallsachen);
        var straf = FuelleAus(VollmachtArt.Strafsache);
        var schreiben = Path.Combine(Arbeitsordner(), "Anspruchsschreiben an HUK 1 Vorlage.docx");
        await File.WriteAllTextAsync(schreiben, "angefangen");

        Dienst().RaeumeAuf(Referenz);

        File.Exists(unfall).Should().BeFalse();
        File.Exists(straf).Should().BeFalse();
        File.Exists(schreiben).Should().BeTrue("ein angefangenes Anspruchsschreiben ist keine Vollmacht");
    }

    [Fact]
    public void Ein_danach_leerer_Arbeitsordner_geht_mit()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        FuelleAus(VollmachtArt.Bussgeldsachen);

        Dienst().RaeumeAuf(Referenz);

        Directory.Exists(Arbeitsordner()).Should().BeFalse();
    }

    /// <summary>
    /// Der Anwalt hat die Vollmacht in Word offen, während er den Dialog
    /// schließt. Das ist kein Fehler: Die Datei bleibt bis zur Startaufräumung
    /// liegen, die anderen gehen trotzdem.
    /// </summary>
    [Fact]
    public void Eine_in_Word_geoeffnete_Datei_bleibt_still_liegen()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        var unfall = FuelleAus(VollmachtArt.Unfallsachen);
        var straf = FuelleAus(VollmachtArt.Strafsache);

        using (new FileStream(unfall, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            var aufraeumen = () => Dienst().RaeumeAuf(Referenz);

            aufraeumen.Should().NotThrow();
        }

        File.Exists(unfall).Should().BeTrue();
        File.Exists(straf).Should().BeFalse();
        Directory.Exists(Arbeitsordner()).Should().BeTrue("darin liegt noch die gesperrte Datei");
    }

    [Fact]
    public void Ohne_Arbeitsordner_legt_das_Aufraeumen_keinen_an()
    {
        Dienst().RaeumeAuf(Referenz);

        Directory.Exists(Arbeitsordner()).Should().BeFalse();
    }

    /// <summary>
    /// Ohne Referenz zeigte der Ordnername auf „Ohne Vorgang" — dort liegen die
    /// frei erfassten Schreiben, und eine Vollmacht entsteht dort nie. „..“ und
    /// „.“ landen ebenfalls dort, sie sind keine Referenz.
    /// </summary>
    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("..")]
    [InlineData(".")]
    public async Task Ohne_Referenz_bleibt_der_Ordner_ohne_Vorgang_unberuehrt(string referenz)
    {
        var ohneVorgang = Arbeitsordner(referenz);
        Directory.CreateDirectory(ohneVorgang);
        var datei = Path.Combine(ohneVorgang, VollmachtArten.Dateiname(VollmachtArt.Strafsache));
        await File.WriteAllTextAsync(datei, "keine Vollmacht dieses Vorgangs");

        Dienst().RaeumeAuf(referenz);

        File.Exists(datei).Should().BeTrue();
    }

    public void Dispose()
    {
        _umgebung.Dispose();
        if (Directory.Exists(_vorlagenOrdner))
        {
            Directory.Delete(_vorlagenOrdner, true);
        }
    }

    private sealed class KeinDrucker : IWordDrucker
    {
        public Task<string?> DruckeAsync(string docxPfad, CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("Das Aufräumen druckt nicht.");
    }
}
