using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// Das Update im E2E-Testmodus (#196) über HTTP, so wie die Suite es fährt:
/// <c>POST api/Simulation/aktualisierung</c> stellt den Fall ein und setzt den
/// Stand zurück, dann prüfen, laden, installieren. Quelle und Start sind die
/// Attrappen aus <c>Program.cs</c>; die Quelle ist nur ohne Pause je Block
/// neu gebaut, damit die Last den Download nicht aufhält. Nichts geht nach außen, nichts wird
/// gestartet; die einzige Spur ist eine Zeile in <c>protokoll.jsonl</c>.
///
/// Wie die Suite gegen einen einzigen Dienst: ein Wirt für die ganze Klasse.
/// </summary>
public sealed class AktualisierungTestmodusEndpunktTests(AktualisierungTestmodusEndpunktTests.Wirt wirt)
    : IClassFixture<AktualisierungTestmodusEndpunktTests.Wirt>
{
    private static readonly Uri Fall = new("/api/Simulation/aktualisierung", UriKind.Relative);

    private int InstallerZeilen() => wirt.Testmodus.Zeilen()
        .Count(zeile => zeile.Aktion == TestmodusProtokoll.AktualisierungInstaller);

    private async Task<HttpClient> StelleEin(bool pruefsummeFalsch)
    {
        var client = wirt.Fabrik.CreateClient();
        (await client.PostAsJsonAsync(Fall, new { pruefsummeFalsch })).StatusCode.Should().Be(HttpStatusCode.NoContent);
        return client;
    }

    [Fact]
    public async Task Mit_falscher_Pruefsumme_endet_es_in_fehler_und_der_Installer_startet_nicht()
    {
        var client = await StelleEin(pruefsummeFalsch: true);
        var vorher = InstallerZeilen();

        var geprueft = await client.PostAsync(AktualisierungsWirt.Schritt("pruefen"), content: null);
        (await geprueft.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("neueVersion").GetString().Should().Be("9.9.9");
        (await client.PostAsync(AktualisierungsWirt.Schritt("herunterladen"), content: null))
            .StatusCode.Should().Be(HttpStatusCode.Accepted);

        var fehler = await AktualisierungsWirt.WarteAuf(client, "fehler");

        fehler.GetProperty("meldung").GetString().Should().Contain("stimmt nicht mit der veröffentlichten überein");
        fehler.GetProperty("fehlerArt").GetString().Should().Be("pruefung", "danach wählt das Frontend den Satz, nicht nach dem Wortlaut");
        (await client.PostAsync(AktualisierungsWirt.Schritt("installieren"), content: null))
            .StatusCode.Should().Be(HttpStatusCode.Conflict);
        InstallerZeilen().Should().Be(vorher, "der Installer startet nicht");
    }

    [Fact]
    public async Task Im_guten_Fall_schreibt_installieren_eine_Protokollzeile()
    {
        var client = await StelleEin(pruefsummeFalsch: false);
        var vorher = InstallerZeilen();
        (await client.PostAsync(AktualisierungsWirt.Schritt("pruefen"), content: null)).EnsureSuccessStatusCode();
        (await client.PostAsync(AktualisierungsWirt.Schritt("herunterladen"), content: null)).EnsureSuccessStatusCode();
        await AktualisierungsWirt.WarteAuf(client, "bereit");

        var antwort = await client.PostAsync(AktualisierungsWirt.Schritt("installieren"), content: null);

        antwort.StatusCode.Should().Be(HttpStatusCode.Accepted);
        InstallerZeilen().Should().Be(vorher + 1);
        File.Exists(wirt.Aktualisierung.Ordner.Merkdatei).Should().BeTrue("die Merkdatei ist auch im Testmodus echt");
        wirt.Fabrik.Services.GetRequiredService<IHerunterfahrenNachInstallerStart>()
            .Should().BeOfType<TestmodusHerunterfahren>("die Suite fährt danach weitere Durchläufe gegen denselben Dienst");
        wirt.Fabrik.Services.GetRequiredService<IHostApplicationLifetime>().ApplicationStopping.IsCancellationRequested
            .Should().BeFalse();
    }

    /// <summary>
    /// Die Suite fährt alle Durchläufe gegen denselben Dienst: Das Einstellen
    /// des Falls setzt den Stand zurück, auch nach einem fertigen Download.
    /// </summary>
    [Fact]
    public async Task Das_Einstellen_des_Falls_setzt_den_Stand_zurueck()
    {
        var client = await StelleEin(pruefsummeFalsch: false);
        await client.PostAsync(AktualisierungsWirt.Schritt("pruefen"), content: null);
        await client.PostAsync(AktualisierungsWirt.Schritt("herunterladen"), content: null);
        await AktualisierungsWirt.WarteAuf(client, "bereit");

        await StelleEin(pruefsummeFalsch: false);

        (await client.GetFromJsonAsync<JsonElement>(AktualisierungsWirt.Stand))
            .GetProperty("zustand").GetString().Should().Be("unbekannt");
        Directory.EnumerateFiles(wirt.Aktualisierung.Ordner.Pfad, "Automation_App_Setup_*").Should().BeEmpty();
    }

    /// <summary>Ein Testwirt im Testmodus mit eigenem Aktualisierungs- und Testmodus-Ordner.</summary>
    public sealed class Wirt : IDisposable
    {
        public Wirt()
        {
            // Dieselbe Attrappe wie im Testmodus, nur ohne die 150 ms je Block: Keiner dieser Tests
            // beobachtet „laedt" oder bricht ab; die Pause machte sie nur von der Last abhängig.
            // Dass der Testmodus die Attrappe verdrahtet, prüft TestmodusInjectionTests.
            Fabrik = new AktualisierungsWirt(
                Aktualisierung.Ordner,
                quelle: new TestmodusAktualisierungsQuelle(TimeSpan.Zero),
                testmodusOrdner: Testmodus.Ordner);
        }

        internal AktualisierungsUmgebung Aktualisierung { get; } = new();

        internal TestmodusUmgebung Testmodus { get; } = new();

        internal AktualisierungsWirt Fabrik { get; }

        public void Dispose()
        {
            Fabrik.Dispose();
            Aktualisierung.Dispose();
            Testmodus.Dispose();
        }
    }
}
