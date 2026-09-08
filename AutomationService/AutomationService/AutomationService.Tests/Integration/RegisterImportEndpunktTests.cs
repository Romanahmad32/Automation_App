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
/// Prüft den Registerimport über die Leitung, mit der Datei als Rohtext.
///
/// Die Fachregeln stehen in den Unit-Tests; hier geht es um das, was die nicht
/// sehen können: dass ASP.NET die camelCase-Felder der Datei überhaupt in das
/// DTO bindet, dass <c>uebernehmen</c> als Abfrageparameter ankommt, dass die
/// Kurzform mit <c>jahrgang</c> und <c>zeilen</c> gelesen wird und dass eine
/// unbekannte Formatfassung als 400 zurückkommt statt halb gelesen zu werden.
/// Genau diese Klasse von Fehlern übersteht sonst die ganze grüne Prüfkette und
/// zeigt sich erst als stilles <c>null</c> zur Laufzeit.
///
/// <b>Nur lesende Aufrufe.</b> Der Testwirt spricht denselben Dienst mit
/// derselben Datenbank an wie die App. Ohne <c>uebernehmen=true</c> verändert
/// der Endpunkt nichts — wer hier einen schreibenden Aufruf ergänzt, schreibt
/// in das Register des Anwenders.
/// </summary>
public class RegisterImportEndpunktTests : IClassFixture<WebApplicationFactory<Program>>
{
    private static readonly Uri Endpunkt = new("/api/RegisterImport", UriKind.Relative);

    private readonly WebApplicationFactory<Program> _factory;

    public RegisterImportEndpunktTests(WebApplicationFactory<Program> factory)
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

    [Fact]
    public async Task Vorschau_liest_die_Datei_und_schreibt_nichts()
    {
        // Ein Jahrgang weit ausserhalb des Bestands — der Aufruf ist ohne
        // uebernehmen ohnehin folgenlos.
        var antwort = await Sende("""
        {
          "version": 1,
          "jahrgaenge": [
            {
              "jahrgang": 1999,
              "zeilen": [
                {
                  "laufendeNummer": 2,
                  "spalte1": "3",
                  "aktenzeichen": "02/99",
                  "abteilung": "C 03o",
                  "mandant": "Zzz Pruefzeile",
                  "sachart": "Bußgeldsache",
                  "rechtsgebiet": "Verkehrsrecht",
                  "sicherheit": "mittel",
                  "hinweise": ["Prueflauf"]
                }
              ]
            }
          ]
        }
        """);

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);

        var bericht = await Lies(antwort);
        bericht.GetProperty("angewendet").GetBoolean().Should().BeFalse(
            "ohne uebernehmen=true darf eine abgeschickte Datei nichts veraendern");

        var jahrgang = bericht.GetProperty("jahrgaenge")[0];
        jahrgang.GetProperty("jahrgang").GetInt32().Should().Be(1999);
        jahrgang.GetProperty("luecken")[0].GetInt32().Should().Be(1);
        jahrgang.GetProperty("neu").GetInt32().Should().Be(1);

        var eintrag = jahrgang.GetProperty("eintraege")[0];
        eintrag.GetProperty("zeile").GetInt32().Should().Be(1, "die Zeilennummer zählt je Jahrgang ab 1");
        eintrag.GetProperty("anzeigetext").GetString().Should().Be("Bußgeldsache Zzz Pruefzeile");
        eintrag.GetProperty("sicherheit").GetString().Should().Be("mittel");
        eintrag.GetProperty("zuPruefen").GetBoolean().Should().BeTrue();
        eintrag.GetProperty("befunde")[0].GetString().Should().Contain("Spalte 1");
        eintrag.GetProperty("hinweise")[0].GetString().Should().Be("Prueflauf");
    }

    /// <summary>
    /// Die Kurzform ist der Normalfall der Jahrgangs-Anleitung: ein Jahrgang,
    /// zwei Felder auf oberster Ebene. Bindet sie nicht, käme ein leerer
    /// Bericht statt eines Fehlers zurück.
    /// </summary>
    [Fact]
    public async Task Die_Kurzform_mit_jahrgang_und_zeilen_wird_gelesen()
    {
        var antwort = await Sende("""
        {
          "jahrgang": 1999,
          "zeilen": [
            { "laufendeNummer": 1, "aktenzeichen": "01/99", "abteilung": "C03", "mandant": "Zzz Pruefzeile" }
          ]
        }
        """);

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);

        var bericht = await Lies(antwort);
        bericht.GetProperty("jahrgaenge").GetArrayLength().Should().Be(1);
        bericht.GetProperty("jahrgaenge")[0].GetProperty("zeilen").GetInt32().Should().Be(1);
    }

    [Fact]
    public async Task Eine_unbekannte_Formatfassung_wird_abgelehnt()
    {
        var antwort = await Sende("""{ "version": 2, "jahrgaenge": [] }""");

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
          "jahrgang": 1999,
          "zeilen": [{ "laufendeNummer": 1, "bemerkungDesErzeugers": "irgendwas" }]
        }
        """);

        antwort.StatusCode.Should().Be(
            HttpStatusCode.OK,
            "eine fehlende version gilt als 1, und ein unbekanntes Feld wird ignoriert");
    }

    /// <summary>
    /// Der Abfrageparameter muss ankommen — und zwar so, dass sein Fehlen die
    /// harmlose Betriebsart ist. Geprüft wird deshalb nur der Weg, der nichts
    /// schreibt: <c>uebernehmen=false</c> ausdrücklich gesetzt.
    /// </summary>
    [Fact]
    public async Task Der_Abfrageparameter_uebernehmen_kommt_an()
    {
        var antwort = await _factory.CreateClient().PostAsync(
            new Uri("/api/RegisterImport?uebernehmen=false", UriKind.Relative),
            new StringContent("""{ "jahrgang": 1999, "zeilen": [] }""", Encoding.UTF8, "application/json"));

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);
        (await Lies(antwort)).GetProperty("angewendet").GetBoolean().Should().BeFalse();
    }

    private Task<HttpResponseMessage> Sende(string datei) =>
        _factory.CreateClient().PostAsync(
            Endpunkt,
            new StringContent(datei, Encoding.UTF8, "application/json"));

    private static async Task<JsonElement> Lies(HttpResponseMessage antwort) =>
        JsonDocument.Parse(await antwort.Content.ReadAsStringAsync()).RootElement.Clone();
}
