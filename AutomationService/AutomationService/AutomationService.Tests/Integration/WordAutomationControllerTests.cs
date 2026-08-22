using System.Net;
using System.Net.Http.Json;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

public class WordAutomationControllerTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public WordAutomationControllerTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["WordAutomation:TemplatesDirectory"] = "Templates",
                    ["WordAutomation:OutputDirectory"] = "Generated",
                    // Tests sollen kein Word starten — Warmup nur in der echten App.
                    ["PdfConversion:WarmupOnStartup"] = "false"
                });
            });
        });
    }

    [Fact]
    public async Task GenerateReplacedDocument_WithEmptyPatterns_ReturnsBadRequest()
    {
        var client = _factory.CreateClient();
        var payload = new WordReplacementDto
        {
            TemplateFilePath = "irrelevant.docx",
            ReplacePatterns = new Dictionary<string, string>()
        };

        var response = await client.PostAsJsonAsync("/api/WordAutomation/replaced-document", payload);

        // [ApiController] validiert das Modell automatisch und liefert hier ProblemDetails (400).
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GenerateReplacedDocument_WhenTemplateIsMissing_ReturnsNotFound()
    {
        var client = _factory.CreateClient();
        var payload = new WordReplacementDto
        {
            TemplateFilePath = Path.Combine(Path.GetTempPath(), $"missing_{Guid.NewGuid():N}.docx"),
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" }
        };

        var response = await client.PostAsJsonAsync("/api/WordAutomation/replaced-document", payload);

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        var body = await response.Content.ReadFromJsonAsync<ReplacedDocumentResponseDto>();
        body.Should().NotBeNull();
        body!.ErrorCode.Should().Be("template_not_found");
        body.Success.Should().BeFalse();
    }

    [Fact]
    public async Task ArbeitsordnerAufraeumen_OhneVorhandenenOrdner_MeldetErfolg()
    {
        var client = _factory.CreateClient();
        var payload = new ArbeitsordnerDto { VorgangSchluessel = $"99/26 C03_XX-YY {Guid.NewGuid():N}" };

        var response = await client.PostAsJsonAsync("/api/WordAutomation/arbeitsordner/aufraeumen", payload);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<ArbeitsordnerAufgeraeumtDto>();
        body.Should().NotBeNull();
        body!.Success.Should().BeTrue();
    }

    [Fact]
    public async Task CalculateRvgFees_WithValidRequest_ReturnsCalculation()
    {
        var client = _factory.CreateClient();
        var payload = new RvgCalculationRequestDto
        {
            Gegenstandswert = 2810.87m,
            Gebuehrensatz = 1.3m,
            ApplyVat = false
        };

        var response = await client.PostAsJsonAsync("/api/WordAutomation/rvg-calculation", payload);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<RvgCalculationResponseDto>();
        body.Should().NotBeNull();
        body!.Success.Should().BeTrue();
        // Erwartungswerte aus RvgFeeCalculator: 51,50 + 3×41,50 + 1×59,50 = 235,50 €.
        body.Wertgebuehr.Should().Be(235.50m);
        body.Geschaeftsgebuehr.Should().Be(306.15m);
        body.Auslagenpauschale.Should().Be(20.00m);
        body.Netto.Should().Be(326.15m);
        body.Umsatzsteuer.Should().Be(0m);
        body.Brutto.Should().Be(326.15m);
    }

    [Fact]
    public async Task CalculateRvgFees_WithVat_ReturnsVatAmounts()
    {
        var client = _factory.CreateClient();
        var payload = new RvgCalculationRequestDto
        {
            Gegenstandswert = 2810.87m,
            Gebuehrensatz = 1.3m,
            ApplyVat = true
        };

        var response = await client.PostAsJsonAsync("/api/WordAutomation/rvg-calculation", payload);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await response.Content.ReadFromJsonAsync<RvgCalculationResponseDto>();
        body!.Umsatzsteuer.Should().Be(61.97m);
        body.Brutto.Should().Be(388.12m);
    }

    [Fact]
    public async Task CalculateRvgFees_WithNonPositiveGegenstandswert_ReturnsBadRequest()
    {
        var client = _factory.CreateClient();
        var payload = new RvgCalculationRequestDto { Gegenstandswert = 0m };

        var response = await client.PostAsJsonAsync("/api/WordAutomation/rvg-calculation", payload);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}
