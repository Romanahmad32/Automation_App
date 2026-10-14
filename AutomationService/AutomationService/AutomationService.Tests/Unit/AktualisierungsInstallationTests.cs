using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der letzte Schritt (#196): Setup-Datei erneut prüfen, Merkdatei schreiben,
/// Installer losgelöst starten — mit genau den Schaltern, die
/// <c>installer/setup.iss</c> erwartet, und nie mit
/// <c>/FORCECLOSEAPPLICATIONS</c>, das ein Word mit ungespeichertem Schriftsatz
/// beenden könnte. Gestartet wird hier nichts: Der Start ist eine Attrappe.
/// </summary>
public sealed class AktualisierungsInstallationTests : IDisposable
{
    private readonly AktualisierungsUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    [Fact]
    public async Task Installieren_startet_das_Setup_mit_genau_diesen_Schaltern()
    {
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        var schritt = dienst.Installiere();

        schritt.Ablehnung.Should().BeNull();
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Bereit);
        var aufruf = _umgebung.Starter.Aufrufe.Should().ContainSingle().Subject;
        var log = Path.Combine(_umgebung.Ordner.Pfad, "installer-1.4.0.log");
        aufruf.Argumente.Should().Be($"/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NEUSTART=1 /LOG=\"{log}\"");
        aufruf.Argumente.Should().NotContainEquivalentOf("FORCECLOSEAPPLICATIONS");
        aufruf.SetupPfad.Should().Be(_umgebung.SetupPfad);
        aufruf.Arbeitsordner.Should().Be(_umgebung.Ordner.Pfad, "nie der Programmordner, den das Setup ersetzt");
        aufruf.ZielVersion.Should().Be("1.4.0");
    }

    [Fact]
    public void Ein_Pfad_mit_Leerzeichen_steht_in_Anfuehrungszeichen()
    {
        var aufruf = InstallerAufruf.Fuer(
            @"C:\Users\Max Mustermann\AppData\Local\AutomationService\Aktualisierung\Automation_App_Setup_1.4.0.exe",
            @"C:\Users\Max Mustermann\AppData\Local\AutomationService\Aktualisierung\installer-1.4.0.log",
            @"C:\Users\Max Mustermann\AppData\Local\AutomationService\Aktualisierung",
            Versionsnummer.Lies("1.4.0")!);

        aufruf.Argumente.Should().EndWith(@"/LOG=""C:\Users\Max Mustermann\AppData\Local\AutomationService\Aktualisierung\installer-1.4.0.log""");
    }

    [Fact]
    public async Task Die_Merkdatei_liegt_schon_da_wenn_der_Installer_startet()
    {
        Merkzettel? beimStart = null;
        _umgebung.Starter.BeimStart = _ => beimStart = _umgebung.Merkdatei.Lies();
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        dienst.Installiere();

        beimStart.Should().NotBeNull("die App beendet sich gleich nach dem Start — danach schreibt niemand mehr");
        beimStart!.ZielVersion.Should().Be("1.4.0");
        File.Exists(_umgebung.Ordner.Merkdatei + ".neu").Should().BeFalse("geschrieben wird atomar");
    }

    /// <summary>
    /// Der Dienst macht dem Setup Platz — auch einer, den die App beim Start
    /// nur übernommen hat und der deshalb keinen Wächter auf sie hat. Angestoßen
    /// wird erst, wenn der Installer läuft; heruntergefahren erst danach
    /// (<c>GeordnetesHerunterfahrenTests</c>).
    /// </summary>
    [Fact]
    public async Task Nach_dem_Start_des_Installers_faehrt_der_Dienst_herunter()
    {
        int? anstoesseBeimStart = null;
        _umgebung.Starter.BeimStart = _ => anstoesseBeimStart = _umgebung.Herunterfahren.Anstoesse;
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);
        _umgebung.Herunterfahren.Anstoesse.Should().Be(0, "laden allein beendet nichts");

        dienst.Installiere().Ablehnung.Should().BeNull();

        anstoesseBeimStart.Should().Be(0, "erst der laufende Installer gibt den Anstoß");
        _umgebung.Herunterfahren.Anstoesse.Should().Be(1);
    }

    [Fact]
    public async Task Ein_zweiter_Klick_startet_kein_zweites_Setup()
    {
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        dienst.Installiere();
        var nochmal = dienst.Installiere();

        nochmal.Ablehnung.Should().BeNull();
        _umgebung.Starter.Aufrufe.Should().HaveCount(1);
        _umgebung.Herunterfahren.Anstoesse.Should().Be(1);
    }

    public static TheoryData<string, Action<string>, string, AktualisierungsFehlerArt> Austausch => new()
    {
        {
            "verändert",
            pfad =>
            {
                var inhalt = File.ReadAllBytes(pfad);
                inhalt[0] ^= 0xFF;
                File.WriteAllBytes(pfad, inhalt);
            },
            AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.PruefsummeFalsch),
            AktualisierungsFehlerArt.Pruefung
        },
        {
            "verkürzt",
            pfad => File.WriteAllBytes(pfad, File.ReadAllBytes(pfad)[..^1]),
            AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.GroesseFalsch),
            AktualisierungsFehlerArt.Pruefung
        },
        // Weg statt falsch: „kam nicht vollständig an" träfe nicht zu.
        { "gelöscht", File.Delete, AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.Fehlt), AktualisierungsFehlerArt.Sonstig },
    };

    /// <summary>
    /// Zwischen Download und Klick auf „Installieren" liegt die Datei auf der
    /// Platte. Ausgeführt wird, was dann dort liegt — also wird es vor dem
    /// Start noch einmal geprüft.
    /// </summary>
    [Theory]
    [MemberData(nameof(Austausch))]
    public async Task Eine_nach_dem_Download_veraenderte_Datei_wird_nicht_gestartet(
        string fall,
        Action<string> veraendere,
        string meldung,
        AktualisierungsFehlerArt art)
    {
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);
        veraendere(_umgebung.SetupPfad);

        var schritt = dienst.Installiere();

        schritt.Ablehnung.Should().Be(meldung, fall);
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Fehler);
        schritt.Stand.Meldung.Should().Be(meldung);
        schritt.Stand.FehlerArt.Should().Be(art, fall);
        _umgebung.Starter.Aufrufe.Should().BeEmpty();
        _umgebung.Herunterfahren.Anstoesse.Should().Be(0, "ohne Installer bleibt der Dienst an");
        File.Exists(_umgebung.SetupPfad).Should().BeFalse("eine verworfene Datei bleibt nicht liegen");
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse("ohne Start nichts zu melden");
    }

    [Fact]
    public async Task Scheitert_der_Start_gibt_es_keine_Merkdatei_und_eine_Meldung()
    {
        _umgebung.Starter.Ausnahme = new System.ComponentModel.Win32Exception(1260, "Durch Richtlinie blockiert");
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        var schritt = dienst.Installiere();

        schritt.Ablehnung.Should().Be(AktualisierungsMeldungen.StartGescheitert);
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Fehler);
        schritt.Stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Sonstig);
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse("es läuft kein Setup, also gibt es nichts zu melden");
        _umgebung.Herunterfahren.Anstoesse.Should().Be(0, "ohne laufendes Setup braucht der Anwalt den Dienst weiter");
    }
}
