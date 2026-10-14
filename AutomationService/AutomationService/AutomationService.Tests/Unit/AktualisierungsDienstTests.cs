using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Zustandsfolge der Aktualisierung (#196): prüfen, laden, abbrechen — und
/// was der Dienst ablehnt (im Controller ein 409). Quelle und Installer-Start
/// sind Attrappen; nichts geht ins Netz, nichts wird gestartet.
/// </summary>
public sealed class AktualisierungsDienstTests : IDisposable
{
    private readonly AktualisierungsUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    [Fact]
    public async Task Verfuegbar_laedt_bereit_mit_Fortschritt()
    {
        _umgebung.Quelle.Verzoegerung = TimeSpan.FromMilliseconds(300);
        using var dienst = _umgebung.Dienst();
        dienst.Stand().Zustand.Should().Be(AktualisierungsZustand.Unbekannt, "geprüft wird erst auf Anforderung");

        var geprueft = await dienst.PruefeAsync(CancellationToken.None);

        geprueft.Should().BeEquivalentTo(new AktualisierungsStand(
            AktualisierungsUmgebung.LaufendeVersion,
            "1.4.0",
            AktualisierungsZustand.Verfuegbar,
            0,
            _umgebung.Quelle.Inhalt.Length,
            null,
            null,
            QuelleAttrappe.Adresse.AbsoluteUri,
            null));
        _umgebung.Quelle.Downloads.Should().Be(0, "heruntergeladen wird erst nach dem Klick");

        var schritt = dienst.StarteDownload();
        schritt.Ablehnung.Should().BeNull();
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Laedt);

        var unterwegs = await AktualisierungsUmgebung.WarteBis(
            dienst, stand => stand.GeladenBytes > 0, "erste Bytes");
        unterwegs.Zustand.Should().Be(AktualisierungsZustand.Laedt);
        unterwegs.GeladenBytes.Should().BeLessThan(_umgebung.Quelle.Inhalt.Length);
        File.Exists(_umgebung.SetupPfad).Should().BeFalse("unterwegs liegt nur die Teildatei");

        var bereit = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Bereit);
        bereit.GeladenBytes.Should().Be(_umgebung.Quelle.Inhalt.Length);
        bereit.Meldung.Should().BeNull();
        File.ReadAllBytes(_umgebung.SetupPfad).Should().Equal(_umgebung.Quelle.Inhalt);
        File.Exists(_umgebung.Teildatei).Should().BeFalse("nach der Prüfung bekommt die Datei ihren Namen");
        _umgebung.Starter.Aufrufe.Should().BeEmpty("heruntergeladen ist noch nicht installiert");
    }

    [Fact]
    public async Task Ein_zweites_Herunterladen_startet_keinen_zweiten_Download()
    {
        _umgebung.Quelle.Verzoegerung = TimeSpan.FromMilliseconds(50);
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);

        dienst.StarteDownload();
        var nochmal = dienst.StarteDownload();

        nochmal.Ablehnung.Should().BeNull("ein Doppelklick ist kein Fehler");
        nochmal.Stand.Zustand.Should().Be(AktualisierungsZustand.Laedt);
        await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Bereit);
        dienst.StarteDownload().Stand.Zustand.Should().Be(AktualisierungsZustand.Bereit);
        _umgebung.Quelle.Downloads.Should().Be(1);
    }

    [Fact]
    public async Task Pruefen_waehrend_bereit_fragt_nicht_neu_und_laesst_den_Zustand()
    {
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        var stand = await dienst.PruefeAsync(CancellationToken.None);

        stand.Zustand.Should().Be(AktualisierungsZustand.Bereit);
        _umgebung.Quelle.Abfragen.Should().Be(1);
    }

    [Fact]
    public async Task Ohne_neuere_Version_ist_der_Stand_aktuell()
    {
        using var dienst = _umgebung.Dienst(laufendeVersion: "1.4.0+def5678");

        var stand = await dienst.PruefeAsync(CancellationToken.None);

        stand.Zustand.Should().Be(AktualisierungsZustand.Aktuell);
        stand.NeueVersion.Should().BeNull();
        stand.DownloadUrl.Should().BeNull();
        stand.Meldung.Should().BeNull();
    }

    [Fact]
    public async Task Ohne_Netz_bleibt_der_Stand_unbekannt_mit_Meldung()
    {
        _umgebung.Quelle.Ausnahme = new HttpRequestException("Kein Netz");
        using var dienst = _umgebung.Dienst();

        var stand = await dienst.PruefeAsync(CancellationToken.None);

        stand.Zustand.Should().Be(AktualisierungsZustand.Unbekannt);
        stand.Meldung.Should().Be(AktualisierungsMeldungen.NichtGeprueft);
        stand.Meldung.Should().NotContain("Kein Netz", "der Anwender liest nie den Text einer Ausnahme");
        stand.FehlerArt.Should().BeNull("eine Ursache trägt nur der Zustand fehler");
    }

    [Fact]
    public async Task Eine_verschluckte_Anfrage_endet_am_Zeitlimit_statt_zu_haengen()
    {
        _umgebung.Optionen.PruefZeitlimit = TimeSpan.FromMilliseconds(200);
        _umgebung.Quelle.Antwortzeit = TimeSpan.FromMinutes(5);
        using var dienst = _umgebung.Dienst();

        var pruefen = dienst.PruefeAsync(CancellationToken.None);

        (await Task.WhenAny(pruefen, Task.Delay(TimeSpan.FromMinutes(2)))).Should().BeSameAs(pruefen);
        (await pruefen).Zustand.Should().Be(AktualisierungsZustand.Unbekannt);
    }

    [Fact]
    public async Task Ohne_Pruefsumme_wird_nicht_geladen_aber_der_Rueckfallweg_bleibt()
    {
        _umgebung.Quelle.Digest = "";
        using var dienst = _umgebung.Dienst();

        var stand = await dienst.PruefeAsync(CancellationToken.None);
        var schritt = dienst.StarteDownload();

        stand.Zustand.Should().Be(AktualisierungsZustand.Fehler);
        stand.Meldung.Should().Contain("1.4.0").And.Contain("Prüfsumme");
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Sonstig, "es liegt an der Veröffentlichung, nicht an der Leitung");
        stand.DownloadUrl.Should().Be(QuelleAttrappe.Adresse.AbsoluteUri);
        schritt.Ablehnung.Should().Be(stand.Meldung);
        _umgebung.Quelle.Downloads.Should().Be(0);
    }

    [Fact]
    public async Task Abbrechen_loescht_die_Teildatei_und_fuehrt_zurueck_auf_verfuegbar()
    {
        _umgebung.Quelle.Verzoegerung = TimeSpan.FromSeconds(1);
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.StarteDownload();
        await AktualisierungsUmgebung.WarteBis(dienst, stand => stand.GeladenBytes > 0, "erste Bytes");
        File.Exists(_umgebung.Teildatei).Should().BeTrue("sonst prüfte das Löschen nichts");

        var stand = await dienst.BrecheAbAsync();

        stand.Zustand.Should().Be(AktualisierungsZustand.Verfuegbar);
        stand.GeladenBytes.Should().Be(0);
        stand.Meldung.Should().BeNull("abgebrochen hat der Anwender selbst");
        stand.FehlerArt.Should().BeNull();
        File.Exists(_umgebung.Teildatei).Should().BeFalse();
        File.Exists(_umgebung.SetupPfad).Should().BeFalse();

        _umgebung.Quelle.Verzoegerung = TimeSpan.Zero;
        dienst.StarteDownload().Ablehnung.Should().BeNull("nach dem Abbruch geht es von vorn");
        await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Bereit);
    }

    [Fact]
    public async Task Abbrechen_ohne_laufenden_Download_aendert_nichts()
    {
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        (await dienst.BrecheAbAsync()).Zustand.Should().Be(AktualisierungsZustand.Bereit);
        File.Exists(_umgebung.SetupPfad).Should().BeTrue();
    }

    [Fact]
    public void Herunterladen_ohne_Pruefung_wird_abgelehnt()
    {
        using var dienst = _umgebung.Dienst();

        var schritt = dienst.StarteDownload();

        schritt.Ablehnung.Should().Be(AktualisierungsMeldungen.KeineNeueVersion);
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Unbekannt);
        _umgebung.Quelle.Downloads.Should().Be(0);
    }

    [Fact]
    public async Task Herunterladen_ohne_neue_Version_wird_abgelehnt()
    {
        using var dienst = _umgebung.Dienst(laufendeVersion: "1.4.0");
        await dienst.PruefeAsync(CancellationToken.None);

        var schritt = dienst.StarteDownload();

        schritt.Ablehnung.Should().Be(AktualisierungsMeldungen.KeineNeueVersion);
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Aktuell);
    }

    [Fact]
    public async Task Installieren_vor_bereit_wird_abgelehnt()
    {
        _umgebung.Quelle.Verzoegerung = TimeSpan.FromMilliseconds(100);
        using var dienst = _umgebung.Dienst();

        dienst.Installiere().Ablehnung.Should().Be(AktualisierungsMeldungen.NichtBereit, "noch nicht geprüft");
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.Installiere().Ablehnung.Should().Be(AktualisierungsMeldungen.NichtBereit, "nur verfügbar");
        dienst.StarteDownload();
        dienst.Installiere().Ablehnung.Should().Be(AktualisierungsMeldungen.NichtBereit, "noch beim Laden");

        _umgebung.Starter.Aufrufe.Should().BeEmpty();
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse();
        await dienst.BrecheAbAsync();
    }
}
