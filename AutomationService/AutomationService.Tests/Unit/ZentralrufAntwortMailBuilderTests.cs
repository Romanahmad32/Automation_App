using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Entwickler-Simulation ist nur so gut wie ihr Mailtext: Er muss vom
/// echten <see cref="ZentralrufReplyParser"/> genauso vollständig ausgewertet
/// werden wie eine echte Antwort. Diese Tests halten Builder und Parser
/// zusammen — reißt eines von beiden aus, fällt es hier auf.
/// </summary>
public sealed class ZentralrufAntwortMailBuilderTests
{
    private readonly ZentralrufReplyParser _parser = new();

    [Fact]
    public void GebauteAntwort_WirdVollstaendigGeparst()
    {
        var text = ZentralrufAntwortMailBuilder.Build(
            referenz: "84/26 C03_GG-XY 123",
            kennzeichen: "GG-XY 123",
            unfallDatum: "09.03.2026",
            anfrageDatum: "01.07.2026",
            versichererName: "HUK-COBURG (Simulation)",
            typ: SimulationAntwortTyp.Versicherer);

        var data = _parser.Parse(text);

        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.ReferenzAuftragsnummer.Should().Be("84");
        data.ReferenzJahr.Should().Be("26");
        data.ReferenzAbteilung.Should().Be("C03");
        data.ReferenzKennzeichen.Should().Be("GG-XY 123");
        data.Kennzeichen.Should().Be("GG-XY 123");
        data.UnfallDatum.Should().Be("09.03.2026");
        data.AnfrageDatum.Should().Be("01.07.2026");
        data.VersichererName.Should().Be("HUK-COBURG (Simulation)");
        data.VersichererStrasse.Should().Be("Lyoner Str. 10");
        data.VersichererPlz.Should().Be("60524");
        data.VersichererOrt.Should().Be("Frankfurt");
        data.VersicherungsscheinNr.Should().Be("999/123456-X");
        data.KeinVersichererErmittelt.Should().BeFalse();
    }

    [Fact]
    public void NegativAntwort_WirdAlsKeinVersichererErkannt()
    {
        var text = ZentralrufAntwortMailBuilder.Build(
            referenz: "84/26 C03_GG-XY 123",
            kennzeichen: "GG-XY 123",
            unfallDatum: "09.03.2026",
            anfrageDatum: "01.07.2026",
            versichererName: "egal",
            typ: SimulationAntwortTyp.KeinVersicherer);

        var data = _parser.Parse(text);

        data.KeinVersichererErmittelt.Should().BeTrue();
        data.VersichererName.Should().BeNull();
        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
    }

    [Fact]
    public void Zwischennachricht_WirdAlsSolcheErkannt()
    {
        var text = ZentralrufAntwortMailBuilder.Build(
            referenz: "84/26 C03_GG-XY 123",
            kennzeichen: "GG-XY 123",
            unfallDatum: "09.03.2026",
            anfrageDatum: "01.07.2026",
            versichererName: "egal",
            typ: SimulationAntwortTyp.Zwischennachricht);

        var data = _parser.Parse(text);

        data.Zwischennachricht.Should().BeTrue();
        data.KeinVersichererErmittelt.Should().BeFalse();
        data.VersichererName.Should().BeNull();
        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.UnfallDatum.Should().Be("09.03.2026");
    }
}
