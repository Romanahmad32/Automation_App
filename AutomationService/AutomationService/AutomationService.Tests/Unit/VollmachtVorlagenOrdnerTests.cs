using AutomationService.Features.Vollmacht.Domain.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Unterordner <c>Vollmacht/</c> (§4.11): feste Dateinamen, sichtbarer
/// Stand, und ein Saatgut, das nie eine Datei der Kanzlei überschreibt.
/// </summary>
public sealed class VollmachtVorlagenOrdnerTests : IDisposable
{
    private readonly string _wurzel = Path.Combine(Path.GetTempPath(), $"VollmachtOrdner_{Guid.NewGuid():N}");

    private string VorlagenOrdner => Path.Combine(_wurzel, "Vorlagen");

    private string MusterOrdner => Path.Combine(_wurzel, "Templates", "Vollmacht");

    private VollmachtVorlagenOrdner Ordner() =>
        new(VorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance);

    private void LegeMusterAn()
    {
        Directory.CreateDirectory(MusterOrdner);
        foreach (var art in VollmachtArten.Alle)
        {
            File.WriteAllText(Path.Combine(MusterOrdner, VollmachtArten.Mustername(art)), "Muster");
        }
    }

    [Fact]
    public void Das_Saatgut_ueberschreibt_keine_Vorlage_der_Kanzlei()
    {
        LegeMusterAn();
        var eigene = Ordner().PfadFuer(VollmachtArt.Unfallsachen);
        Directory.CreateDirectory(Path.GetDirectoryName(eigene)!);
        File.WriteAllText(eigene, "Kanzleikopf");

        var kopiert = Ordner().Ergaenze(MusterOrdner);

        kopiert.Should().Be(2);
        File.ReadAllText(eigene).Should().Be("Kanzleikopf");
        File.ReadAllText(Ordner().PfadFuer(VollmachtArt.Strafsache)).Should().Be("Muster");
    }

    [Fact]
    public void Ein_zweiter_Lauf_kopiert_nichts_mehr()
    {
        LegeMusterAn();
        Ordner().Ergaenze(MusterOrdner);

        Ordner().Ergaenze(MusterOrdner).Should().Be(0);
    }

    [Fact]
    public void Der_Stand_nennt_je_Art_Datei_und_ob_sie_da_ist()
    {
        var vorhanden = Ordner().PfadFuer(VollmachtArt.Bussgeldsachen);
        Directory.CreateDirectory(Path.GetDirectoryName(vorhanden)!);
        File.WriteAllText(vorhanden, "x");

        var stand = Ordner().Stand();

        stand.Select(v => v.Dateiname).Should().Equal(
            "Vollmacht Unfallsachen.docx", "Vollmacht Bussgeldsachen.docx", "Vollmacht Strafsache.docx");
        stand.Select(v => v.Vorhanden).Should().Equal(false, true, false);
        stand[1].GeaendertAm.Should().NotBeNull();
        stand[0].GeaendertAm.Should().BeNull();
    }

    /// <summary>
    /// „Ordner öffnen" soll auch vor der ersten Datei einen Ordner finden,
    /// in den der Anwalt sie legen kann.
    /// </summary>
    [Fact]
    public void Der_Stand_legt_den_leeren_Unterordner_an()
    {
        Ordner().Stand();

        Directory.Exists(Path.Combine(VorlagenOrdner, "Vollmacht")).Should().BeTrue();
    }

    [Fact]
    public void Jede_Art_findet_sich_ueber_ihren_Vertragswert_wieder()
    {
        foreach (var art in VollmachtArten.Alle)
        {
            VollmachtArten.AusWert(VollmachtArten.Wert(art)).Should().Be(art);
        }

        VollmachtArten.AusWert("verkehrsrecht").Should().BeNull();
        VollmachtArten.Mustername(VollmachtArt.Bussgeldsachen).Should().Be("Muster_Vollmacht_Bussgeldsachen.docx");
    }

    public void Dispose()
    {
        if (Directory.Exists(_wurzel))
        {
            Directory.Delete(_wurzel, true);
        }
    }
}
