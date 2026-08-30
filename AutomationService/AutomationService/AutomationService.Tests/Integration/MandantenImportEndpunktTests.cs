using System.Net;
using System.Text;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Prüft den Importendpunkt über die Leitung, mit der Datei als Rohtext.
///
/// Die Fachregeln stehen in den Unit-Tests; hier geht es um das, was die nicht
/// sehen kann: dass ASP.NET die camelCase-Felder der Datei überhaupt in das
/// DTO bindet, dass <c>uebernehmen</c> als Abfrageparameter ankommt und dass
/// eine unbekannte Formatfassung als 400 zurückkommt statt halb gelesen zu
/// werden. Genau diese Klasse von Fehlern übersteht sonst die ganze grüne
/// Prüfkette und zeigt sich erst als stilles <c>null</c> zur Laufzeit.
///
/// <b>Nur lesende Aufrufe.</b> Der Testwirt spricht denselben Dienst mit
/// derselben Datenbank an wie die App. Ohne <c>uebernehmen=true</c> verändert
/// der Endpunkt nichts — wer hier einen schreibenden Aufruf ergänzt, schreibt
/// in das Register des Anwenders.
/// </summary>
public class MandantenImportEndpunktTests : IClassFixture<WebApplicationFactory<Program>>
{
    private static readonly Uri Endpunkt = new("/api/MandantenImport", UriKind.Relative);

    private readonly WebApplicationFactory<Program> _factory;

    public MandantenImportEndpunktTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Development");
            builder.ConfigureAppConfiguration((_, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["PdfConversion:WarmupOnStartup"] = "false"
                });
            });
        });
    }

    [Fact]
    public async Task Vorschau_liest_die_Datei_und_schreibt_nichts()
    {
        // Ein Name und ein Ordner, die es im Bestand nicht gibt — der Aufruf
        // ist ohne uebernehmen ohnehin folgenlos.
        var antwort = await Sende("""
        {
          "version": 1,
          "mandanten": [
            {
              "vorname": "Zzz",
              "nachname": "Pruefzeile",
              "ort": "Bad Homburg",
              "aktenOrdnernamen": ["ZZZ Pruefordner ohne Bestand"],
              "kennzeichen": ["HG-E 1427"],
              "quelle": "Prueflauf",
              "sicherheit": "hoch"
            }
          ],
          "ohneMandantenbezug": []
        }
        """);

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);

        var bericht = await Lies(antwort);
        bericht.GetProperty("angewendet").GetBoolean().Should().BeFalse(
            "ohne uebernehmen=true darf eine abgeschickte Datei nichts veraendern");

        var eintraege = bericht.GetProperty("eintraege");
        eintraege.GetArrayLength().Should().Be(1);

        var eintrag = eintraege[0];
        eintrag.GetProperty("zeile").GetInt32().Should().Be(0);
        eintrag.GetProperty("anzeigename").GetString().Should().Be("Zzz Pruefzeile");
        eintrag.GetProperty("sicherheit").GetString().Should().Be("hoch");
        eintrag.GetProperty("art").GetString().Should().BeOneOf(
            "neu", "ergaenzt", "unveraendert", "abgelehnt");
    }

    [Fact]
    public async Task Eine_unbekannte_Formatfassung_wird_abgelehnt()
    {
        var antwort = await Sende("""{ "version": 2, "mandanten": [] }""");

        antwort.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        (await antwort.Content.ReadAsStringAsync()).Should().Contain("Fassung 2");
    }

    // Der Erzeuger der Datei ist ein Programm, kein Formular: ein Feld, das er
    // zusaetzlich mitschickt, darf die ganze Datei nicht zu Fall bringen.
    [Fact]
    public async Task Unbekannte_Felder_werden_uebergangen()
    {
        var antwort = await Sende("""
        {
          "mandanten": [
            { "vorname": "Zzz", "nachname": "Pruefzeile", "bemerkungDesErzeugers": "irgendwas" }
          ]
        }
        """);

        antwort.StatusCode.Should().Be(
            HttpStatusCode.OK,
            "eine fehlende version gilt als 1, und ein unbekanntes Feld wird ignoriert");
    }

    private Task<HttpResponseMessage> Sende(string datei) =>
        _factory.CreateClient().PostAsync(
            Endpunkt,
            new StringContent(datei, Encoding.UTF8, "application/json"));

    private static async Task<JsonElement> Lies(HttpResponseMessage antwort) =>
        JsonDocument.Parse(await antwort.Content.ReadAsStringAsync()).RootElement.Clone();
}
