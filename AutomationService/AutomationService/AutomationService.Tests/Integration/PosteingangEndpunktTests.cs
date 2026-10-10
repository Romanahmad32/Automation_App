using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Die Handgriffe am Posteingang (§4.3) über HTTP: Anhang holen, Nachricht als
/// <c>.eml</c> ablegen, das Versandprotokoll über alle Vorgänge lesen.
///
/// Geprüft wird hier der Weg <b>ohne eingerichtetes Postfach</b> — der Zustand,
/// in dem die App ausgeliefert wird. Er muss eine verständliche deutsche
/// Meldung und 400 ergeben und nicht eine Zeitüberschreitung gegen einen
/// Server, den es nicht gibt: Der Anwalt soll lesen, was zu tun ist, statt zu
/// warten. Der erfolgreiche Abruf gegen ein echtes IMAP-Postfach ist kein
/// Integrationstest, sondern liegt in <c>PosteingangAnhaengeTests</c> am
/// Ordner-Proxy.
/// </summary>
public class PosteingangEndpunktTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public PosteingangEndpunktTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
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
    [InlineData("/api/mailbox/nachrichten/egal/anhaenge/2")]
    [InlineData("/api/mailbox/nachrichten/egal/eml")]
    public async Task OhnePostfachZugang_MeldetDerDienstWasZuTunIst(string pfad)
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync(new Uri(pfad, UriKind.Relative));

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>();
        problem.Should().NotBeNull();
        problem!.Detail.Should().Contain("Einstellungen");
    }

    [Fact]
    public async Task Versandprotokoll_LiefertAlleVorgaengeAufEinmal()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync(
            new Uri("/api/EmailVersand/protokoll/alle?limit=5", UriKind.Relative));

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var eintraege = await response.Content.ReadFromJsonAsync<List<Dictionary<string, object>>>();
        eintraege.Should().NotBeNull();
    }
}
