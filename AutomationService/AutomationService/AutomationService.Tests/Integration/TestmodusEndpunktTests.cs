using System.Net;
using System.Net.Http.Json;
using System.Reflection;
using System.Text.Json;
using AutomationService.Tests.Unit;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Der E2E-Testmodus (#168) durch den echten <c>Program.cs</c>: Was die
/// Unit-Tests an der Verdrahtung prüfen, muss auch in der Reihenfolge der
/// Registrierungen dort halten.
///
/// <b>Konfiguration über <c>CreateHost</c> + <c>ConfigureHostConfiguration</c>,
/// nicht über <c>ConfigureAppConfiguration</c>.</b> Der Testmodus wird bei der
/// Registrierung entschieden, also vor <c>Build()</c>; Werte aus
/// <c>ConfigureAppConfiguration</c> sieht die App erst danach. Die
/// Host-Konfiguration reicht der Testwirt als Kommandozeile an den Einstieg —
/// genau der Weg, auf dem auch <c>scripts/e2e-start.ps1</c> den Dienst startet.
///
/// Geprüft wird nur, was nichts auslöst: <c>/health</c>, die Druckerauskunft,
/// die Auflösung der Nähte im Container und die zwei Ablehnungen (Microsoft-
/// Anmeldung, Outlook-Signaturen). Eine Zentralruf-Anfrage oder ein Versand
/// über einen hier fehlerhaft verdrahteten Dienst ginge echt hinaus.
/// </summary>
public sealed class TestmodusEndpunktTests(TestmodusEndpunktTests.TestmodusFabrik fabrik)
    : IClassFixture<TestmodusEndpunktTests.TestmodusFabrik>
{
    [Fact]
    public async Task Health_meldet_den_Testmodus()
    {
        var antwort = await fabrik.CreateClient().GetAsync(new Uri("/health", UriKind.Relative));

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);
        using var json = JsonDocument.Parse(await antwort.Content.ReadAsStringAsync());
        json.RootElement.GetProperty("testmodus").ValueKind.Should().Be(JsonValueKind.True);
    }

    [Fact]
    public async Task Der_Vollmacht_Dialog_nennt_keinen_echten_Drucker()
    {
        var drucker = await fabrik.CreateClient().GetFromJsonAsync<JsonElement>(
            new Uri("/api/Vollmacht/drucker", UriKind.Relative));

        drucker.GetProperty("name").GetString().Should().Be("Testmodus (kein Druck)");
        drucker.GetProperty("zustand").GetString().Should().Be("bereit");
    }

    /// <summary>
    /// Die neun Nähte im Container des echten <c>Program.cs</c> — nicht in
    /// einer nachgebauten Registrierung wie in den Unit-Tests. Hier zeigt sich,
    /// ob eine Zeile in <c>Program.cs</c> nach dem Testmodus noch einen echten
    /// Dienst nachgeschoben hat.
    /// </summary>
    [Theory]
    [MemberData(nameof(NaehteDerUnitTests))]
    public void Im_vollen_Host_loest_jede_Naht_zur_Attrappe_auf(Type naht, Type attrappe)
    {
        using var bereich = fabrik.Services.CreateScope();

        bereich.ServiceProvider.GetRequiredService(naht).Should().BeOfType(attrappe);
    }

    public static TheoryData<Type, Type> NaehteDerUnitTests()
    {
        var daten = new TheoryData<Type, Type>();
        foreach (var zeile in TestmodusInjectionTests.Naehte)
        {
            daten.Add((Type)zeile[0], (Type)zeile[3]);
        }

        return daten;
    }

    /// <summary>
    /// Ein Hintergrunddienst löst die Nähte beim Start auf, noch vor der
    /// ersten Anfrage — der Zentralruf-Warmup startete so einen echten
    /// Browser. Gehalten wird eine Naht in einem Feld (auch der primäre
    /// Konstruktor legt eines an); jedes davon muss die Attrappe sein.
    /// </summary>
    [Fact]
    public void Kein_Hintergrunddienst_haelt_einen_echten_Aussenweg()
    {
        var naehte = TestmodusInjectionTests.Naehte.Select(zeile => (Type)zeile[0]).ToHashSet();
        var attrappen = TestmodusInjectionTests.Naehte.Select(zeile => (Type)zeile[3]).ToHashSet();

        var gehalten = fabrik.Services.GetServices<IHostedService>()
            .SelectMany(dienst => dienst.GetType()
                .GetFields(BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public)
                .Where(feld => naehte.Contains(feld.FieldType))
                .Select(feld => (Dienst: dienst.GetType().Name, Wert: feld.GetValue(dienst))))
            .ToList();

        gehalten.Should().NotBeEmpty("der Zentralruf-Warmup hält die Naht — sonst prüft dieser Test nichts");
        gehalten.Should().OnlyContain(
            eintrag => eintrag.Wert != null && attrappen.Contains(eintrag.Wert.GetType()),
            "kein Hintergrunddienst darf eine echte Naht halten: {0}",
            string.Join(", ", gehalten.Where(e => e.Wert == null || !attrappen.Contains(e.Wert.GetType())).Select(e => e.Dienst)));
    }

    [Fact]
    public async Task Die_Microsoft_Anmeldung_wird_mit_409_abgelehnt()
    {
        var antwort = await fabrik.CreateClient().PostAsync(
            new Uri("/api/Mailbox/microsoft/signin", UriKind.Relative), content: null);

        antwort.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await antwort.Content.ReadAsStringAsync())
            .Should().Contain("Im Testmodus ist die Anmeldung bei Microsoft abgeschaltet.");
    }

    [Fact]
    public async Task Die_Outlook_Signaturen_kommen_leer_zurueck()
    {
        var signaturen = await fabrik.CreateClient().GetFromJsonAsync<JsonElement>(
            new Uri("/api/EmailVersand/signaturen", UriKind.Relative));

        signaturen.ValueKind.Should().Be(JsonValueKind.Array);
        signaturen.GetArrayLength().Should().Be(0);
    }

    [Fact]
    public async Task Eine_Signatur_laesst_sich_im_Testmodus_nicht_aus_Outlook_uebernehmen()
    {
        var antwort = await fabrik.CreateClient().PostAsJsonAsync(
            new Uri("/api/EmailVersand/signaturen/uebernehmen", UriKind.Relative),
            new { name = "Kanzlei" });

        antwort.IsSuccessStatusCode.Should().BeFalse();
        (await antwort.Content.ReadAsStringAsync()).Should().Contain("Testmodus");
    }

    /// <summary>
    /// Die Gegenprobe zum Weg oben: Kommt der Schalter erst nach der
    /// Registrierung an, sind die echten Dienste verdrahtet — und /health darf
    /// dann keinen Testmodus melden, sonst übernähme die App diesen Dienst.
    /// </summary>
    [Fact]
    public async Task Ein_erst_nach_der_Registrierung_gesetzter_Testmodus_wird_nicht_gemeldet()
    {
        using var spaet = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.ConfigureAppConfiguration((_, konfiguration) =>
                konfiguration.AddInMemoryCollection(new Dictionary<string, string?>(TestmodusFabrik.Grundwerte)
                {
                    ["Simulation:Testmodus"] = "true",
                })));

        var antwort = await spaet.CreateClient().GetAsync(new Uri("/health", UriKind.Relative));

        using var json = JsonDocument.Parse(await antwort.Content.ReadAsStringAsync());
        json.RootElement.GetProperty("testmodus").ValueKind.Should().Be(JsonValueKind.False);
    }

    /// <summary>Ein Testwirt im Testmodus, Umgebung Development wie jeder Testwirt.</summary>
    public sealed class TestmodusFabrik : WebApplicationFactory<Program>
    {
        /// <summary>Was in keinem Testwirt anlaufen soll: Word-Warmup und automatische Sicherung.</summary>
        internal static readonly IReadOnlyDictionary<string, string?> Grundwerte = new Dictionary<string, string?>
        {
            ["PdfConversion:WarmupOnStartup"] = "false",
            ["Backup:AutomatischeSicherung"] = "false",
        };

        protected override IHost CreateHost(IHostBuilder builder)
        {
            ArgumentNullException.ThrowIfNull(builder);

            builder.ConfigureHostConfiguration(konfiguration =>
                konfiguration.AddInMemoryCollection(new Dictionary<string, string?>(Grundwerte)
                {
                    ["Simulation:Enabled"] = "true",
                    ["Simulation:Testmodus"] = "true",
                }));
            return base.CreateHost(builder);
        }
    }
}
