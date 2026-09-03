using System.Net;
using System.Net.Http.Json;
using AutomationService.Core.Lifetime;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Der Health-Endpunkt ist kein Beiwerk: das Frontend startet den Dienst und
/// zeigt seine Oberflaeche erst, wenn dieser Endpunkt 200 liefert. Aendert sich
/// hier Pfad, Statuscode oder Feldname, startet die Anwendung nicht mehr —
/// gemerkt haette man es sonst erst im ausgelieferten Build.
/// </summary>
public class HealthEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public HealthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    // Tests sollen kein Word starten — Warmup nur in der echten App.
                    ["PdfConversion:WarmupOnStartup"] = "false",
                    // Und keine automatische Sicherung anstossen — die
                    // Datenbank selbst liegt dank TestAppDataUmgebung schon in
                    // einem Temp-Verzeichnis, dieser Schalter ist nur der
                    // zusaetzliche Not-Aus.
                    ["Backup:AutomatischeSicherung"] = "false",
                });
            });
        });
    }

    [Fact]
    public async Task Health_meldet_nach_vollstaendigem_Start_bereit()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync(new Uri("/health", UriKind.Relative));

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var antwort = await response.Content.ReadFromJsonAsync<HealthAntwort>();
        antwort.Should().NotBeNull();
        antwort!.Status.Should().Be("bereit");
        antwort.Version.Should().NotBeNullOrWhiteSpace();
    }
}
