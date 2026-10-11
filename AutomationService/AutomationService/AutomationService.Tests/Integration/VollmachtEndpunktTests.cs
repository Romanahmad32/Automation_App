using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Der Rand von <c>api/Vollmacht</c> (§4.11). Fachlich geprüft wird in
/// <see cref="Unit.VollmachtDienstTests"/>; hier nur, was die Unit-Tests nicht
/// sehen: dass eine unbekannte Art am Rand abprallt, bevor irgendetwas
/// ausgefüllt oder gar gedruckt wird, und dass das Aufräumen eine Referenz
/// verlangt.
///
/// <b>Kein gültiger Auftrag.</b> Der Testwirt spricht denselben Vorlagenordner
/// und — bei gültiger Art — denselben Drucker an wie die App.
/// </summary>
public class VollmachtEndpunktTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public VollmachtEndpunktTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Development");
            builder.ConfigureAppConfiguration((_, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["PdfConversion:WarmupOnStartup"] = "false",
                    ["Backup:AutomatischeSicherung"] = "false",
                });
            });
        });
    }

    [Theory]
    [InlineData("drucken")]
    [InlineData("oeffnen")]
    public async Task Eine_unbekannte_Art_ergibt_400(string weg)
    {
        var antwort = await _factory.CreateClient().PostAsJsonAsync(
            new Uri($"/api/Vollmacht/{weg}", UriKind.Relative),
            new { art = "verkehrsrecht", referenz = "1/26 C03_XX" });

        antwort.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await antwort.Content.ReadAsStringAsync()).Should().Contain("verkehrsrecht");
    }

    /// <summary>
    /// Ohne Referenz zeigte das Aufräumen auf den Arbeitsordner „Ohne Vorgang",
    /// den sich alle frei erfassten Schreiben teilen (#174).
    /// </summary>
    [Fact]
    public async Task Aufraeumen_ohne_Referenz_ergibt_400()
    {
        var antwort = await _factory.CreateClient().PostAsJsonAsync(
            new Uri("/api/Vollmacht/aufraeumen", UriKind.Relative),
            new { referenz = "" });

        antwort.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    /// <summary>
    /// Eine Referenz, zu der es keinen Arbeitsordner gibt — das Frontend räumt
    /// beim Schließen auf, ohne zu wissen, ob noch etwas liegt. Kein Fehler.
    /// </summary>
    [Fact]
    public async Task Aufraeumen_ohne_Arbeitsordner_ergibt_204()
    {
        var antwort = await _factory.CreateClient().PostAsJsonAsync(
            new Uri("/api/Vollmacht/aufraeumen", UriKind.Relative),
            new { referenz = $"1/26 C03_XX {Guid.NewGuid():N}" });

        antwort.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }
}
