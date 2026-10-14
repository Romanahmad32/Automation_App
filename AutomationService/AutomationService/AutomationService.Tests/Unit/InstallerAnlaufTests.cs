using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Anlauffrist nach dem Installer-Start (#196): Beendet sich das Setup
/// sofort wieder — ein zweites Setup hält den <c>SetupMutex</c>, ein
/// Virenscanner bricht es ab —, darf der Dienst nicht herunterfahren, sonst
/// schlösse sich auch die App, und der Anwalt stünde ohne App und ohne Update
/// da. Gewartet wird hier nie wirklich: Die Attrappe antwortet sofort.
/// </summary>
public sealed class InstallerAnlaufTests : IDisposable
{
    private readonly AktualisierungsUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    [Fact]
    public void Die_Anlauffrist_ist_drei_Sekunden_und_endet_vor_dem_Herunterfahren()
    {
        InstallerStart.Anlauffrist.Should().Be(TimeSpan.FromSeconds(3));
        (InstallerStart.Anlauffrist + GeordnetesHerunterfahren.Verzoegerung + TimeSpan.FromSeconds(60))
            .Should().BeLessThan(TimeSpan.FromSeconds(90), "das Setup wartet ab seinem Start höchstens 90 s auf den Dienst");
    }

    [Fact]
    public async Task Laeuft_das_Setup_nach_der_Frist_noch_faehrt_der_Dienst_herunter()
    {
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        var schritt = dienst.Installiere();

        schritt.Ablehnung.Should().BeNull();
        var lauf = _umgebung.Starter.Laeufe.Should().ContainSingle().Subject;
        lauf.Frist.Should().Be(InstallerStart.Anlauffrist);
        lauf.Entsorgt.Should().BeTrue("das Prozess-Handle bleibt nicht offen");
        _umgebung.Herunterfahren.Anstoesse.Should().Be(1);
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeTrue("der nächste Start meldet das Ergebnis");
    }

    [Fact]
    public async Task Beendet_sich_das_Setup_sofort_bleibt_der_Dienst_an_und_meldet_fehler()
    {
        _umgebung.Starter.SofortBeendetMit = 1;
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        var schritt = dienst.Installiere();

        schritt.Ablehnung.Should().Be(AktualisierungsMeldungen.SofortBeendet);
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Fehler);
        schritt.Stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Sonstig);
        schritt.Stand.Meldung.Should().Be(AktualisierungsMeldungen.SofortBeendet);
        _umgebung.Herunterfahren.Anstoesse.Should().Be(0, "ohne laufendes Setup braucht der Anwalt den Dienst weiter");
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse("es wurde nichts installiert, also gibt es nichts zu melden");
        File.Exists(_umgebung.SetupPfad).Should().BeTrue("die Datei ist geprüft und darf liegen bleiben");
        _umgebung.Starter.Laeufe.Should().ContainSingle().Which.Entsorgt.Should().BeTrue();
    }

    /// <summary>
    /// Nach dem sofort beendeten Setup gilt der Installer nicht als gestartet:
    /// „Erneut versuchen" lädt neu, und der nächste Start fährt den Dienst herunter.
    /// </summary>
    [Fact]
    public async Task Nach_einem_sofort_beendeten_Setup_geht_der_naechste_Versuch_durch()
    {
        _umgebung.Starter.SofortBeendetMit = 1;
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);
        dienst.Installiere();

        _umgebung.Starter.SofortBeendetMit = null;
        await AktualisierungsUmgebung.LadeBisBereit(dienst);
        var schritt = dienst.Installiere();

        schritt.Ablehnung.Should().BeNull();
        _umgebung.Starter.Aufrufe.Should().HaveCount(2);
        _umgebung.Herunterfahren.Anstoesse.Should().Be(1);
    }

    [Fact]
    public void Ohne_Prozess_Handle_gilt_das_Setup_als_laufend()
    {
        using var lauf = new InstallerProzess(prozess: null);

        lauf.WarteAufEnde(TimeSpan.FromSeconds(3)).Should().BeNull(
            "mit Shell gestartet kann Process.Start null liefern, obwohl das Setup läuft");
    }
}
