using System.Text.Json;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Update-Attrappen des E2E-Testmodus (#196): eine Quelle, die ein
/// erfundenes 9.9.9 mit einer kleinen Datei im Speicher meldet, und ein
/// Installer-Start, der nichts startet und nur seine Spur hinterlässt. Dazwischen
/// laufen Auswahl, Download, Prüfung und Merkdatei echt — genau das soll ein
/// Testlauf sehen.
/// </summary>
public sealed class TestmodusAktualisierungTests : IDisposable
{
    private readonly AktualisierungsUmgebung _aktualisierung = new();
    private readonly TestmodusUmgebung _testmodus = new();
    private readonly TestmodusAktualisierungsQuelle _quelle = new(verzoegerungJeBlock: TimeSpan.Zero);

    public void Dispose()
    {
        _aktualisierung.Dispose();
        _testmodus.Dispose();
    }

    private AktualisierungsDienst Dienst() => _aktualisierung.Dienst(
        _quelle,
        new TestmodusInstallerStarter(_testmodus.Ordner, _testmodus.Protokoll));

    [Fact]
    public async Task Die_Quelle_meldet_9_9_9_mit_pruefbarer_Setup_Datei()
    {
        var release = await _quelle.HoleNeuesteAsync(CancellationToken.None);

        var auswahl = SetupAuswahl.Waehle(release, AktualisierungsUmgebung.LaufendeVersion);

        auswahl.Art.Should().Be(AuswahlArt.Verfuegbar, "die Attrappe läuft durch dieselbe strenge Auswahl");
        auswahl.NeueVersion!.ToString().Should().Be(TestmodusAktualisierungsQuelle.Version).And.Be("9.9.9");
        auswahl.Setup!.Groesse.Should().Be(1024 * 1024);
        auswahl.Setup.Adresse.Host.Should().Be("testmodus.invalid", "eine .invalid-Adresse löst nie auf");
        auswahl.DownloadUrl.Should().BeNull("an den Browser geht nur https://github.com/… — im Testmodus öffnet kein Klick etwas");
    }

    [Fact]
    public async Task Eine_fremde_Adresse_laedt_die_Quelle_nicht()
    {
        var oeffnen = () => _quelle.OeffneAsync(new Uri("https://github.com/x.exe"), CancellationToken.None);

        await oeffnen.Should().ThrowAsync<HttpRequestException>();
    }

    [Fact]
    public async Task Installieren_schreibt_genau_eine_Protokollzeile_und_startet_nichts()
    {
        using var dienst = Dienst();
        var bereit = await AktualisierungsUmgebung.LadeBisBereit(dienst);
        bereit.NeueVersion.Should().Be("9.9.9");

        dienst.Installiere().Ablehnung.Should().BeNull();

        var zeile = _testmodus.Zeilen().Should().ContainSingle().Subject;
        zeile.Aktion.Should().Be(TestmodusProtokoll.AktualisierungInstaller).And.Be("aktualisierung-installer");
        zeile.Referenz.Should().BeNull();
        zeile.Datei.Should().StartWith("Aktualisierung/").And.EndWith("_installer.json");

        using var ablage = JsonDocument.Parse(File.ReadAllText(_testmodus.VollerPfad(zeile.Datei!)));
        var argumente = ablage.RootElement.GetProperty("argumente").GetString();
        argumente.Should().StartWith("/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NEUSTART=1 /LOG=");
        argumente.Should().NotContainEquivalentOf("FORCECLOSEAPPLICATIONS");
        ablage.RootElement.GetProperty("zielVersion").GetString().Should().Be("9.9.9");
        ablage.RootElement.GetProperty("setupPfad").GetString()
            .Should().Be(_aktualisierung.Ordner.SetupPfad(Versionsnummer.Lies("9.9.9")!));

        _aktualisierung.Merkdatei.Lies()!.ZielVersion.Should().Be("9.9.9", "die Merkdatei ist echt, nur der Start nicht");
    }

    [Fact]
    public async Task Mit_falscher_Pruefsumme_endet_der_Download_in_fehler_und_nichts_startet()
    {
        _quelle.PruefsummeFalsch = true;
        using var dienst = Dienst();
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);

        stand.Meldung.Should().Be(AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.PruefsummeFalsch));
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Pruefung);
        dienst.Installiere().Ablehnung.Should().Be(AktualisierungsMeldungen.NichtBereit);
        _testmodus.Zeilen().Should().BeEmpty("der Installer startet nicht");
        Directory.EnumerateFiles(_aktualisierung.Ordner.Pfad).Should().BeEmpty("die verfälschte Datei ist gelöscht");
    }

    [Fact]
    public async Task Zuruecksetzen_fuehrt_auf_unbekannt_und_loescht_die_Setup_Datei()
    {
        using var dienst = Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);
        dienst.Installiere();

        await dienst.SetzeZurueckAsync();

        dienst.Stand().Zustand.Should().Be(AktualisierungsZustand.Unbekannt);
        dienst.Stand().NeueVersion.Should().BeNull();
        Directory.EnumerateFiles(_aktualisierung.Ordner.Pfad, "Automation_App_Setup_*").Should().BeEmpty();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);
        dienst.Installiere().Ablehnung.Should().BeNull();
        _testmodus.Zeilen().Should().HaveCount(2, "nach dem Zurücksetzen startet der nächste Durchlauf wieder");
    }

    [Fact]
    public async Task Die_Wartezeit_des_Downloads_hoert_auf_den_Abbruch()
    {
        using var langsam = new TestmodusDownloadStream(new byte[10], TimeSpan.FromMinutes(5));
        using var abbruch = new CancellationTokenSource(TimeSpan.FromMilliseconds(100));

        var lesen = async () => await langsam.ReadAsync(new byte[10], abbruch.Token);

        await lesen.Should().ThrowAsync<OperationCanceledException>();
    }
}
