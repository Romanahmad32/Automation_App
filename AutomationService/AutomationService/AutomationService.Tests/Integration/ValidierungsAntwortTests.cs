using System.Net;
using System.Net.Http.Json;
using System.Text;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Prueft den <em>Rumpf</em> einer abgewiesenen Anfrage und nicht nur den Statuscode
/// (#53). Der Statuscode allein war schon vorher richtig — falsch war, was danebenstand:
/// ValidationProblemDetails traegt seine Meldungen ausschliesslich in <c>errors</c>, und
/// die Oberflaeche las deshalb das englische "One or more validation errors occurred."
/// vor. Welches Feld klemmt, stand nirgends, wo es jemand gelesen haette.
///
/// Die Meldungen sind deutsch und nennen das Feld so, wie der Anwalt es kennt. Diese
/// Tests pruefen deshalb den <em>Wortlaut</em> und nicht nur, dass ueberhaupt etwas
/// dasteht — an einem "irgendwas ist ungueltig" faellt sonst nichts auf.
/// </summary>
public class ValidierungsAntwortTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ValidierungsAntwortTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((_, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["WordAutomation:TemplatesDirectory"] = "Templates",
                    ["WordAutomation:OutputDirectory"] = "Generated",
                    ["PdfConversion:WarmupOnStartup"] = "false",
                    ["Backup:AutomatischeSicherung"] = "false",
                });
            });
        });
    }

    [Fact]
    public async Task Unzulaessiger_Gegenstandswert_nennt_Feld_und_Grenzen_auf_Deutsch()
    {
        var problem = await Abgewiesen(
            "/api/WordAutomation/rvg-calculation", "{\"gegenstandswert\": 3000000000}");

        problem.Title.Should().Be("Ungültige Anfrage");
        problem.Detail.Should().Be("Der Gegenstandswert muss zwischen 0 und 100000000 € liegen.");
    }

    /// <summary>
    /// Der leere Rumpf ist der Fall, den <c>[Required]</c> an einem <c>decimal?</c>
    /// ueberhaupt erst abfangen soll (siehe den Kommentar dort). Er muss deshalb auch
    /// beim Anwalt als der ankommen, der er ist — und nicht als 51,50 EUR.
    /// </summary>
    [Fact]
    public async Task Leerer_Rumpf_nennt_das_fehlende_Pflichtfeld()
    {
        var problem = await Abgewiesen("/api/WordAutomation/rvg-calculation", "{}");

        problem.Detail.Should().Be("Der Gegenstandswert muss ausgefüllt sein.");
    }

    /// <summary>
    /// Die Anfrage nennt eine Vorlagendatei, die es nicht gibt. Dass trotzdem 400 und
    /// nicht 404 zurueckkommt, ist der Beleg: Die Laengengrenze greift, bevor die Action
    /// laeuft — der Endpunkt nimmt keine Liste beliebiger Laenge mehr an.
    /// </summary>
    [Fact]
    public async Task Zu_viele_Schadenspositionen_werden_abgewiesen()
    {
        var problem = await Abgewiesen(Enumerable
            .Range(0, 101)
            .Select(nummer => new DamageItemDto { Description = $"Position {nummer}", Amount = 1m }));

        problem.Detail.Should().Be("Die Schadensaufstellung darf höchstens 100 Einträge enthalten.");
    }

    /// <summary>
    /// Der Schluessel aus ModelState ("DamageListing.Items[1].Amount") taucht nicht auf —
    /// nur die Nummer daraus. Sie ist das Einzige an ihm, was die gemeinte Zeile findet.
    /// </summary>
    [Fact]
    public async Task Eine_fehlerhafte_Position_wird_mit_ihrer_Nummer_genannt()
    {
        var problem = await Abgewiesen(
        [
            new DamageItemDto { Description = "Gutachten", Amount = 1m },
            new DamageItemDto { Description = "Abschleppen", Amount = -5m },
        ]);

        problem.Detail.Should().Be("Position 2: Der Betrag muss zwischen 0 und 10000000 € liegen.");
        problem.Detail.Should().NotContain("Items", "der C#-Pfad ist kein Begriff des Anwalts");
    }

    /// <summary>
    /// Hundert unzulaessige Positionen ergaeben hundert Meldungen. In einer Snackbar ist
    /// das kein Text mehr, sondern eine Wand — der Deckel haelt die ersten fuenf und
    /// zaehlt den Rest.
    /// </summary>
    [Fact]
    public async Task Viele_Verstoesse_werden_auf_fuenf_Meldungen_gedeckelt()
    {
        var problem = await Abgewiesen(Enumerable
            .Range(0, 8)
            .Select(nummer => new DamageItemDto { Description = $"Position {nummer}", Amount = -100m }));

        problem.Detail.Should().Contain("und 3 weitere");
        problem.Detail!.Split(" | ").Should().HaveCount(5);
    }

    /// <summary>
    /// Ein Wert der falschen Art kommt nicht von einer Schranke, sondern vom JSON-Leser.
    /// Dessen Meldung traegt Typnamen, Zeilen- und Byte-Nummern — Innenleben, das dem
    /// Anwalt nichts sagt und das er auch nicht beheben kann: den Rumpf baut die App.
    /// </summary>
    [Fact]
    public async Task Ein_unlesbarer_Rumpf_ergibt_einen_Satz_statt_des_Innenlebens()
    {
        var problem = await Abgewiesen(
            "/api/WordAutomation/rvg-calculation", "{\"gegenstandswert\": \"abc\"}");

        problem.Detail.Should().StartWith(
            "Die Anfrage konnte nicht gelesen werden (betroffen: gegenstandswert).");
        problem.Detail.Should().NotContain("LineNumber").And.NotContain("System.");
    }

    /// <summary>
    /// Die Antwortform haengt am Filter und nicht an einer Action — deshalb gilt sie fuer
    /// jeden Controller. Zentralruf trug denselben toten Zweig und steht hier
    /// stellvertretend fuer die anderen.
    /// </summary>
    [Fact]
    public async Task Auch_der_Zentralruf_antwortet_in_dieser_Form()
    {
        var problem = await Abgewiesen("/api/Zentralruf/prefill", "{}");

        problem.Title.Should().Be("Ungültige Anfrage");
        problem.Detail.Should().Contain("Die Abteilung muss ausgefüllt sein.")
            .And.Contain("Das Kennzeichen des Unfallgegners muss ausgefüllt sein.");
    }

    /// <summary>
    /// Der Wachposten fuer alles, was diese Datei nicht einzeln aufzaehlt: Keine dieser
    /// Antworten darf englisch sein. Die Vorgabetexte des Rahmenwerks sind es alle
    /// ("The {0} field is required.", "The JSON value could not be converted…"), und sie
    /// kehren zurueck, sobald irgendwo ein ErrorMessage vergessen wird.
    /// </summary>
    [Theory]
    [InlineData("/api/WordAutomation/rvg-calculation", "{}")]
    [InlineData("/api/WordAutomation/rvg-calculation", "")]
    [InlineData("/api/WordAutomation/rvg-calculation", "{\"gegenstandswert\": ")]
    [InlineData("/api/WordAutomation/rvg-calculation", "{\"gegenstandswert\": 5000, \"gebuehrensatz\": 99}")]
    [InlineData("/api/WordAutomation/replaced-document", "{\"templateFilePath\": \"\"}")]
    [InlineData("/api/Zentralruf/prefill", "{}")]
    public async Task Keine_dieser_Meldungen_ist_englisch(string pfad, string rumpf)
    {
        var problem = await Abgewiesen(pfad, rumpf);

        problem.Detail.Should().NotBeNullOrWhiteSpace();
        problem.Detail.Should()
            .NotContain("field is required")
            .And.NotContain("must be")
            .And.NotContain("The value")
            .And.NotContain("is invalid");
    }

    private async Task<ValidationProblemDetails> Abgewiesen(string pfad, string rumpf)
    {
        var client = _factory.CreateClient();
        using var inhalt = new StringContent(rumpf, Encoding.UTF8, "application/json");

        var response = await client.PostAsync(new Uri(pfad, UriKind.Relative), inhalt);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        problem.Should().NotBeNull();
        return problem!;
    }

    private async Task<ValidationProblemDetails> Abgewiesen(IEnumerable<DamageItemDto> positionen)
    {
        var client = _factory.CreateClient();
        var payload = new WordReplacementDto
        {
            // Absichtlich eine Vorlage, die es nicht gibt: Sie wuerde erst in der Action
            // gesucht, und dorthin darf keine dieser Anfragen kommen.
            TemplateFilePath = Path.Combine(Path.GetTempPath(), $"missing_{Guid.NewGuid():N}.docx"),
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" },
            DamageListing = new DamageListingDto { Items = positionen.ToList() },
        };

        var response = await client.PostAsJsonAsync("/api/WordAutomation/replaced-document", payload);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var problem = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        problem.Should().NotBeNull();
        return problem!;
    }
}
