using System.Net.Http.Json;
using System.Text.Json;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Tests.Integration;
using FluentAssertions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ein Testwirt für <c>api/Aktualisierung</c> (#196) durch den echten
/// <c>Program.cs</c>. Der Aktualisierungsordner ist immer ein eigener: Jeder
/// Wirt räumt beim Start Setup-Dateien weg, und parallele Testklassen teilen
/// sich sonst den Ordner unter <c>AppDataPaths</c>.
///
/// Ohne <paramref name="testmodusOrdner"/> ist der Testmodus aus; dann müssen
/// Quelle, Start und Herunterfahren ersetzt werden, sonst fragte der Test
/// GitHub und beendete sich der Wirt nach dem ersten Installieren selbst. Mit
/// ihm ist er an, und alle drei sind die Attrappen aus <c>Program.cs</c>.
/// </summary>
internal sealed class AktualisierungsWirt(
    AktualisierungsOrdner ordner,
    IAktualisierungsQuelle? quelle = null,
    IInstallerStarter? starter = null,
    IHerunterfahrenNachInstallerStart? herunterfahren = null,
    TestmodusOrdner? testmodusOrdner = null) : WebApplicationFactory<Program>
{
    public static readonly Uri Stand = new("/api/Aktualisierung", UriKind.Relative);

    public static Uri Schritt(string name) => new($"/api/Aktualisierung/{name}", UriKind.Relative);

    /// <summary>Fragt <c>GET api/Aktualisierung</c> ab, bis der Zustand erreicht ist — höchstens 2 min.</summary>
    public static async Task<JsonElement> WarteAuf(HttpClient client, string zustand)
    {
        var frist = DateTime.UtcNow.AddMinutes(2);
        JsonElement stand;
        do
        {
            stand = await client.GetFromJsonAsync<JsonElement>(Stand);
            if (stand.GetProperty("zustand").GetString() == zustand)
            {
                return stand;
            }

            await Task.Delay(50);
        }
        while (DateTime.UtcNow < frist);

        stand.GetProperty("zustand").GetString().Should().Be(zustand, $"innerhalb von 2 min erwartet (Stand: {stand})");
        return stand;
    }

    /// <summary>Der Grund einer Ablehnung — das <c>detail</c> der Problem-Antwort.</summary>
    public static async Task<string?> Ablehnung(HttpResponseMessage antwort)
    {
        ArgumentNullException.ThrowIfNull(antwort);
        using var json = JsonDocument.Parse(await antwort.Content.ReadAsStringAsync());
        return json.RootElement.GetProperty("detail").GetString();
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        // Über die Host-Konfiguration: Der Testmodus wird bei der Registrierung
        // entschieden (siehe TestmodusEndpunktTests).
        builder.ConfigureHostConfiguration(konfiguration =>
            konfiguration.AddInMemoryCollection(new Dictionary<string, string?>(TestmodusEndpunktTests.TestmodusFabrik.Grundwerte)
            {
                ["Simulation:Enabled"] = "true",
                ["Simulation:Testmodus"] = testmodusOrdner is null ? "false" : "true",
            }));
        return base.CreateHost(builder);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        if (testmodusOrdner is null && (quelle is null || starter is null || herunterfahren is null))
        {
            throw new InvalidOperationException(
                "Ohne Testmodus fragte der Wirt GitHub, startete ein echtes Setup und führe danach herunter — "
                + "Quelle, Start und Herunterfahren ersetzen.");
        }

        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<AktualisierungsOrdner>();
            services.AddSingleton(ordner);
            if (quelle is not null)
            {
                services.RemoveAll<IAktualisierungsQuelle>();
                services.AddSingleton(quelle);
            }

            if (starter is not null)
            {
                services.RemoveAll<IInstallerStarter>();
                services.AddSingleton(starter);
            }

            if (herunterfahren is not null)
            {
                services.RemoveAll<IHerunterfahrenNachInstallerStart>();
                services.AddSingleton(herunterfahren);
            }

            if (testmodusOrdner is not null)
            {
                services.RemoveAll<TestmodusOrdner>();
                services.AddSingleton(testmodusOrdner);
            }
        });
    }
}
