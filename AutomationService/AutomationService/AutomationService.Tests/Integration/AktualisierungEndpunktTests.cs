using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using AutomationService.Core.Lifetime;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.HostedServices;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace AutomationService.Tests.Integration;

/// <summary>
/// <c>api/Aktualisierung</c> (#196) durch den echten <c>Program.cs</c>, mit
/// ersetzter Quelle (im Speicher, 9.9.9 — höher als jede Fassung, mit der die
/// Tests gebaut werden) und einem Start, der nichts startet. Fachlich geprüft
/// wird in den Unit-Tests der Aktualisierung; hier Feldnamen, Statuscodes und
/// dass die Verdrahtung den ganzen Bogen trägt.
///
/// Ein Wirt für die ganze Klasse, nicht einer je Test: Jeder Wirt migriert
/// beim Start dieselbe Testdatenbank, und zehn davon nebeneinander legten
/// parallel laufende Klassen mit „database is locked" lahm. Der Stand ist ein
/// Singleton — deshalb setzt jeder Test ihn zuerst zurück.
/// </summary>
public sealed class AktualisierungEndpunktTests(AktualisierungEndpunktTests.Wirt wirt)
    : IClassFixture<AktualisierungEndpunktTests.Wirt>
{
    private async Task<HttpClient> Frisch(IAktualisierungsQuelle? quelle = null)
    {
        var dienst = wirt.Fabrik.Services.GetRequiredService<IAktualisierungsDienst>();
        await dienst.SetzeZurueckAsync();
        dienst.QuittiereErgebnis();
        wirt.Quelle.Innen = quelle ?? new TestmodusAktualisierungsQuelle(TimeSpan.Zero);
        wirt.Umgebung.Starter.SofortBeendetMit = null;
        return wirt.Fabrik.CreateClient();
    }

    [Fact]
    public async Task Der_Stand_traegt_genau_die_Felder_des_Vertrags()
    {
        var antwort = await (await Frisch()).GetAsync(AktualisierungsWirt.Stand);

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);
        var stand = await antwort.Content.ReadFromJsonAsync<JsonElement>();
        stand.EnumerateObject().Select(feld => feld.Name).Should().Equal(
            "laufendeVersion", "neueVersion", "zustand", "geladenBytes", "gesamtBytes", "meldung", "fehlerArt", "downloadUrl", "letzteAktualisierung");
        stand.GetProperty("laufendeVersion").GetString().Should().Be(Programmfassung.Aktuell, "dieselbe Angabe wie /health");
        stand.GetProperty("zustand").GetString().Should().Be("unbekannt", "geprüft wird erst auf Anforderung");
        stand.GetProperty("fehlerArt").ValueKind.Should().Be(JsonValueKind.Null, "nur bei fehler gesetzt");
        stand.GetProperty("letzteAktualisierung").ValueKind.Should().Be(JsonValueKind.Null);
    }

    [Fact]
    public async Task Herunterladen_ohne_neue_Version_ergibt_409()
    {
        var antwort = await (await Frisch()).PostAsync(AktualisierungsWirt.Schritt("herunterladen"), content: null);

        antwort.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await AktualisierungsWirt.Ablehnung(antwort)).Should().Be(AktualisierungsMeldungen.KeineNeueVersion);
    }

    [Fact]
    public async Task Installieren_ohne_bereit_ergibt_409()
    {
        var client = await Frisch();
        var vorher = wirt.Umgebung.Starter.Aufrufe.Count;
        await client.PostAsync(AktualisierungsWirt.Schritt("pruefen"), content: null);

        var antwort = await client.PostAsync(AktualisierungsWirt.Schritt("installieren"), content: null);

        antwort.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await AktualisierungsWirt.Ablehnung(antwort)).Should().Be(AktualisierungsMeldungen.NichtBereit);
        wirt.Umgebung.Starter.Aufrufe.Should().HaveCount(vorher);
    }

    [Fact]
    public async Task Pruefen_herunterladen_installieren()
    {
        var client = await Frisch();
        var vorher = wirt.Umgebung.Starter.Aufrufe.Count;

        var geprueft = await client.PostAsync(AktualisierungsWirt.Schritt("pruefen"), content: null);
        geprueft.StatusCode.Should().Be(HttpStatusCode.OK);
        var verfuegbar = await geprueft.Content.ReadFromJsonAsync<JsonElement>();
        verfuegbar.GetProperty("zustand").GetString().Should().Be("verfuegbar");
        verfuegbar.GetProperty("neueVersion").GetString().Should().Be("9.9.9");
        verfuegbar.GetProperty("gesamtBytes").GetInt64().Should().Be(1024 * 1024);
        verfuegbar.GetProperty("downloadUrl").ValueKind.Should().Be(
            JsonValueKind.Null, "an den Browser geht nur https://github.com/…, die Testmodus-Quelle meldet .invalid");

        var laden = await client.PostAsync(AktualisierungsWirt.Schritt("herunterladen"), content: null);
        laden.StatusCode.Should().Be(HttpStatusCode.Accepted);
        (await laden.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("zustand").GetString()
            .Should().BeOneOf("laedt", "bereit");

        var bereit = await AktualisierungsWirt.WarteAuf(client, "bereit");
        bereit.GetProperty("geladenBytes").GetInt64().Should().Be(1024 * 1024);

        var herunterfahrenVorher = wirt.Umgebung.Herunterfahren.Anstoesse;
        var installieren = await client.PostAsync(AktualisierungsWirt.Schritt("installieren"), content: null);
        installieren.StatusCode.Should().Be(HttpStatusCode.Accepted);
        var aufruf = wirt.Umgebung.Starter.Aufrufe.Skip(vorher).Should().ContainSingle().Subject;
        aufruf.Argumente.Should().Contain("/NEUSTART=1").And.NotContainEquivalentOf("FORCECLOSEAPPLICATIONS");
        aufruf.SetupPfad.Should().StartWith(wirt.Umgebung.Ordner.Pfad);
        wirt.Umgebung.Herunterfahren.Anstoesse.Should().Be(herunterfahrenVorher + 1, "der Dienst macht dem Setup Platz");
    }

    /// <summary>
    /// Beendet sich das Setup sofort wieder, ist das ein 409 mit Zustand
    /// <c>fehler</c>: Das Frontend zeigt dann 2d statt 2e und bleibt offen, und
    /// der Dienst fährt nicht herunter.
    /// </summary>
    [Fact]
    public async Task Ein_sofort_beendetes_Setup_ergibt_409_und_fehler()
    {
        var client = await Frisch();
        await client.PostAsync(AktualisierungsWirt.Schritt("pruefen"), content: null);
        await client.PostAsync(AktualisierungsWirt.Schritt("herunterladen"), content: null);
        await AktualisierungsWirt.WarteAuf(client, "bereit");
        wirt.Umgebung.Starter.SofortBeendetMit = 1;
        var herunterfahrenVorher = wirt.Umgebung.Herunterfahren.Anstoesse;

        var antwort = await client.PostAsync(AktualisierungsWirt.Schritt("installieren"), content: null);

        antwort.StatusCode.Should().Be(HttpStatusCode.Conflict);
        (await AktualisierungsWirt.Ablehnung(antwort)).Should().Be(AktualisierungsMeldungen.SofortBeendet);
        var stand = await client.GetFromJsonAsync<JsonElement>(AktualisierungsWirt.Stand);
        stand.GetProperty("zustand").GetString().Should().Be("fehler");
        stand.GetProperty("fehlerArt").GetString().Should().Be("sonstig");
        stand.GetProperty("meldung").GetString().Should().Be(AktualisierungsMeldungen.SofortBeendet);
        wirt.Umgebung.Herunterfahren.Anstoesse.Should().Be(herunterfahrenVorher, "ohne laufendes Setup bleibt der Dienst an");
    }

    /// <summary>
    /// Der Neustart nach einem gescheiterten Update: Die Merkdatei nennt 9.9.9,
    /// gestartet ist aber noch die alte Fassung — das meldet der Stand, bis das
    /// Frontend quittiert. Ausgewertet wird sie beim Start vom Hintergrunddienst;
    /// hier, weil der Wirt schon läuft, durch denselben Aufruf von Hand.
    /// </summary>
    [Fact]
    public async Task Der_Start_meldet_das_Ergebnis_bis_es_quittiert_ist()
    {
        var client = await Frisch();
        wirt.Umgebung.Merkdatei.Schreibe(new Merkzettel("9.9.9", DateTimeOffset.Now));
        wirt.Fabrik.Services.GetRequiredService<IAktualisierungsDienst>().Initialisiere();

        var stand = await client.GetFromJsonAsync<JsonElement>(AktualisierungsWirt.Stand);

        var letzte = stand.GetProperty("letzteAktualisierung");
        letzte.EnumerateObject().Select(feld => feld.Name).Should().Equal("zielVersion", "erfolgreich");
        letzte.GetProperty("zielVersion").GetString().Should().Be("9.9.9");
        letzte.GetProperty("erfolgreich").GetBoolean().Should().BeFalse();

        var quittiert = await client.PostAsync(AktualisierungsWirt.Schritt("ergebnis-quittieren"), content: null);

        quittiert.StatusCode.Should().Be(HttpStatusCode.NoContent);
        (await client.GetFromJsonAsync<JsonElement>(AktualisierungsWirt.Stand))
            .GetProperty("letzteAktualisierung").ValueKind.Should().Be(JsonValueKind.Null);
        File.Exists(wirt.Umgebung.Ordner.Merkdatei).Should().BeFalse();
    }

    [Fact]
    public void Die_Merkdatei_wertet_ein_Hintergrunddienst_beim_Start_aus()
    {
        wirt.Fabrik.Services.GetServices<IHostedService>().OfType<AktualisierungStartDienst>().Should().ContainSingle();
    }

    [Fact]
    public async Task Abbrechen_fuehrt_zurueck_auf_verfuegbar()
    {
        var client = await Frisch(new TestmodusAktualisierungsQuelle(TimeSpan.FromMilliseconds(200)));
        await client.PostAsync(AktualisierungsWirt.Schritt("pruefen"), content: null);
        await client.PostAsync(AktualisierungsWirt.Schritt("herunterladen"), content: null);

        var antwort = await client.PostAsync(AktualisierungsWirt.Schritt("abbrechen"), content: null);

        antwort.StatusCode.Should().Be(HttpStatusCode.OK);
        (await antwort.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("zustand").GetString().Should().Be("verfuegbar");
        File.Exists(wirt.Umgebung.Ordner.SetupPfad(Versionsnummer.Lies("9.9.9")!) + ".part").Should().BeFalse();
    }

    [Fact]
    public async Task Ohne_Testmodus_laesst_sich_die_Update_Attrappe_nicht_umschalten()
    {
        var antwort = await (await Frisch()).PostAsJsonAsync(
            new Uri("/api/Simulation/aktualisierung", UriKind.Relative),
            new { pruefsummeFalsch = true });

        antwort.StatusCode.Should().Be(HttpStatusCode.Conflict);
    }

    /// <summary>Ein Testwirt ohne Testmodus, mit eigenem Ordner, ersetzter Quelle, Start und Herunterfahren.</summary>
    public sealed class Wirt : IDisposable
    {
        public Wirt()
        {
            Fabrik = new AktualisierungsWirt(Umgebung.Ordner, Quelle, Umgebung.Starter, Umgebung.Herunterfahren);
        }

        internal AktualisierungsUmgebung Umgebung { get; } = new();

        internal UmschaltbareQuelle Quelle { get; } = new(new TestmodusAktualisierungsQuelle(TimeSpan.Zero));

        internal AktualisierungsWirt Fabrik { get; }

        public void Dispose()
        {
            Fabrik.Dispose();
            Umgebung.Dispose();
        }
    }
}
