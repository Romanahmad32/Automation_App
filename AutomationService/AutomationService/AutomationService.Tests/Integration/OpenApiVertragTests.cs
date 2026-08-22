using System.Net;
using System.Text.Json;
using AutomationService.Tests.Support;
using Microsoft.AspNetCore.Hosting;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Haelt den HTTP-Vertrag des Dienstes als versionierte Datei fest
/// (docs/openapi.json) und schlaegt an, sobald der Code davon abweicht.
///
/// Warum das noetig ist: Frontend und Backend sind ueber nichts als
/// Zeichenketten verbunden — 26 Endpunktpfade und die camelCase-Feldnamen der
/// DTOs. Wird im Backend eine DTO-Eigenschaft umbenannt, uebersetzt C#,
/// laufen alle Tests durch, meldet flutter analyze nichts, und das Feld ist
/// zur Laufzeit still null. Das ist die einzige Fehlerklasse, die die gesamte
/// gruene Pruefkette passiert. Der exportierte Vertrag macht sie im Diff
/// sichtbar, und der Frontend-Test http_vertrag_test.dart prueft die Dart-Seite
/// dagegen.
///
/// Weicht der Bestand ab, schreibt der Test die neue Fassung und faellt.
/// Absicht: die Korrektur ist ein `git add docs/openapi.json`, und bis das
/// passiert ist, bleibt die Pruefkette rot — eine Vertragsaenderung soll im
/// Diff auftauchen und nicht unbemerkt durchgehen.
/// </summary>
public class OpenApiVertragTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public OpenApiVertragTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(builder =>
        {
            // MapOpenApi() haengt in Program.cs an IsDevelopment().
            builder.UseEnvironment("Development");
            builder.ConfigureAppConfiguration((_, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    // Kein Word starten, nur das Dokument abholen.
                    ["PdfConversion:WarmupOnStartup"] = "false"
                });
            });
        });
    }

    [Fact]
    public async Task Exportierter_Vertrag_entspricht_dem_Dienst()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync(new Uri("/openapi/v1.json", UriKind.Relative));
        response.StatusCode.Should().Be(
            HttpStatusCode.OK,
            "ohne das OpenAPI-Dokument gibt es keinen pruefbaren Vertrag");

        var aktuell = Normalisiert(await response.Content.ReadAsStringAsync());
        var pfad = Path.Combine(RepoWurzel.Pfad(), "docs", "openapi.json");

        var bestand = File.Exists(pfad)
            ? Normalisiert(File.ReadAllText(pfad))
            : null;

        if (bestand == aktuell)
        {
            return;
        }

        Directory.CreateDirectory(Path.GetDirectoryName(pfad)!);
        File.WriteAllText(pfad, aktuell);

        Assert.Fail(
            $"Der HTTP-Vertrag hat sich geaendert. Die neue Fassung wurde nach " +
            $"docs/openapi.json geschrieben.\n\n" +
            $"Naechster Schritt: den Diff ansehen — ist die Aenderung gewollt? " +
            $"Wenn ja, mitcommitten. Wenn nicht, ist sie soeben im Backend " +
            $"versehentlich entstanden.\n\n" +
            $"Bei einer gewollten Aenderung ausserdem pruefen, ob die Dart-Seite " +
            $"mitzieht (Automation_App_Frontend/test/architecture/http_vertrag_test.dart).");
    }

    /// <summary>
    /// Einheitliche Einrueckung und LF als Zeilenende, damit der Vergleich
    /// nicht an der Zeilenende-Konvertierung von Git scheitert (.gitattributes
    /// checkt auf Windows mit CRLF aus).
    /// </summary>
    private static readonly JsonSerializerOptions Eingerueckt = new() { WriteIndented = true };

    private static string Normalisiert(string json)
    {
        using var dokument = JsonDocument.Parse(json);
        var formatiert = JsonSerializer.Serialize(dokument.RootElement, Eingerueckt);
        return formatiert.Replace("\r\n", "\n", StringComparison.Ordinal).TrimEnd() + "\n";
    }
}
