using System.Net;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Prüft die lesenden Wege der Registerhistorie über die Leitung (§6.2).
///
/// Die Fachregeln stehen in den Unit-Tests; hier geht es um das, was die nicht
/// sehen können: dass die beiden GET-Routen nebeneinander bestehen —
/// <c>/stand</c> und <c>/{id}</c> teilen sich denselben Präfix, und ohne die
/// <c>:int</c>-Beschränkung schluckte die Id-Route den Stand —, dass eine
/// unbekannte Id 404 ergibt statt einer leeren 200, und dass die Antwort in
/// camelCase ankommt.
///
/// <b>Nur lesende Aufrufe.</b> Der Testwirt spricht denselben Dienst mit
/// derselben Datenbank an wie die App; ein <c>PUT</c> hier änderte das Register
/// des Anwenders.
/// </summary>
public class RegisterHistorieEndpunktTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public RegisterHistorieEndpunktTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Development");
            builder.ConfigureAppConfiguration((_, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["PdfConversion:WarmupOnStartup"] = "false",
                    // Keine echte Sicherung in den Ablageordner des Anwalts.
                    ["Backup:AutomatischeSicherung"] = "false",
                });
            });
        });
    }

    /// <summary>
    /// Eine Id, die es nicht geben kann. Antwortete der Dienst darauf mit 200
    /// und einem leeren Rumpf, öffnete der Bearbeiten-Dialog ein leeres
    /// Formular über einer Zeile, die es nicht gibt — und das Speichern
    /// schriebe eine Berichtigung ins Nichts.
    /// </summary>
    [Fact]
    public async Task Eine_unbekannte_Zeile_ergibt_404()
    {
        var antwort = await _factory.CreateClient()
            .GetAsync(new Uri("/api/RegisterHistorie/2147483647", UriKind.Relative));

        antwort.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    /// <summary>
    /// Der Stand muss erreichbar bleiben, obwohl <c>/{id}</c> daneben liegt:
    /// Ohne die <c>:int</c>-Beschränkung an der Id-Route ginge „stand" als Id
    /// durch und käme als Bindungsfehler zurück.
    /// </summary>
    [Fact]
    public async Task Der_Stand_liegt_neben_der_Id_Route_und_bleibt_erreichbar()
    {
        var antwort = await _factory.CreateClient()
            .GetAsync(new Uri("/api/RegisterHistorie/stand", UriKind.Relative));

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);

        var stand = JsonDocument.Parse(await antwort.Content.ReadAsStringAsync()).RootElement;
        stand.TryGetProperty("jahrgaenge", out _).Should().BeTrue("die Felder kommen in camelCase");
        stand.TryGetProperty("fehlendeJahrgaenge", out _).Should().BeTrue();
    }
}
