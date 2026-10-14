using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Was mit einer Setup-Datei geschieht, die nicht die veröffentlichte ist
/// (#196): Sie endet in <c>fehler</c> mit einer Meldung für den Anwender, ist
/// danach von der Platte verschwunden — samt Teildatei —, und der Installer
/// startet nicht. Es gibt keine Authenticode-Signatur; Größe und SHA256 sind
/// die ganze Echtheitsprüfung.
/// </summary>
public sealed class AktualisierungsDownloadPruefungTests : IDisposable
{
    private readonly AktualisierungsUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    public static TheoryData<string, Func<byte[], byte[]>, string> Verfaelschungen => new()
    {
        {
            "zu kurz",
            inhalt => inhalt[..^1000],
            AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.GroesseFalsch)
        },
        {
            "zu lang",
            inhalt => [.. inhalt, 0x4D, 0x5A],
            AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.PruefsummeFalsch)
        },
        {
            "ein Byte anders",
            inhalt =>
            {
                var anders = (byte[])inhalt.Clone();
                anders[anders.Length / 2] ^= 0xFF;
                return anders;
            },
            AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.PruefsummeFalsch)
        },
    };

    [Theory]
    [MemberData(nameof(Verfaelschungen))]
    public async Task Eine_verfaelschte_Datei_endet_in_fehler_ist_geloescht_und_startet_nichts(
        string fall,
        Func<byte[], byte[]> verfaelsche,
        string meldung)
    {
        _umgebung.Quelle.Geliefert = verfaelsche(_umgebung.Quelle.Inhalt);
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);

        stand.Meldung.Should().Be(meldung, fall);
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Pruefung, fall);
        stand.NeueVersion.Should().Be("1.4.0", "der Dialog nennt die Version weiter");
        stand.DownloadUrl.Should().NotBeNull("„Lieber selbst herunterladen“ bleibt");
        File.Exists(_umgebung.SetupPfad).Should().BeFalse();
        File.Exists(_umgebung.Teildatei).Should().BeFalse();

        dienst.Installiere().Ablehnung.Should().Be(AktualisierungsMeldungen.NichtBereit);
        _umgebung.Starter.Aufrufe.Should().BeEmpty();
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse();
    }

    [Fact]
    public async Task Ein_falscher_Digest_der_Quelle_verwirft_die_echte_Datei()
    {
        _umgebung.Quelle.Digest = "sha256:" + new string('0', 64);
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);

        stand.Meldung.Should().Be(AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.PruefsummeFalsch));
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Pruefung);
        Directory.EnumerateFiles(_umgebung.Ordner.Pfad).Should().BeEmpty();
    }

    [Fact]
    public async Task Eine_abgerissene_Leitung_endet_in_fehler_ohne_Teildatei()
    {
        _umgebung.Quelle.AbrissNach = 100_000;
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);

        stand.Meldung.Should().Be(AktualisierungsMeldungen.Unterbrochen);
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Verbindung);
        stand.GeladenBytes.Should().Be(0);
        File.Exists(_umgebung.Teildatei).Should().BeFalse();
        File.Exists(_umgebung.SetupPfad).Should().BeFalse();
    }

    [Fact]
    public async Task Eine_stockende_Leitung_endet_am_Leerlauf_in_fehler()
    {
        using var umgebung = new AktualisierungsUmgebung(leerlauf: TimeSpan.FromMilliseconds(200));
        umgebung.Quelle.Verzoegerung = TimeSpan.FromMinutes(5);
        using var dienst = umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);

        stand.Meldung.Should().Be(AktualisierungsMeldungen.Stockt);
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Verbindung);
        File.Exists(umgebung.Teildatei).Should().BeFalse();
    }

    [Fact]
    public async Task Nach_einem_Fehler_geht_es_mit_Herunterladen_weiter()
    {
        _umgebung.Quelle.Geliefert = _umgebung.Quelle.Inhalt[..10];
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);
        dienst.StarteDownload();
        await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);

        _umgebung.Quelle.Geliefert = null;
        dienst.StarteDownload().Ablehnung.Should().BeNull();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Bereit);
        stand.Meldung.Should().BeNull("die Meldung des gescheiterten Versuchs gilt nicht mehr");
        stand.FehlerArt.Should().BeNull("ebenso wenig seine Ursache");
        _umgebung.Quelle.Downloads.Should().Be(2);
    }

    [Fact]
    public void Die_Pruefung_vergleicht_Groesse_und_SHA256_an_der_Datei()
    {
        Directory.CreateDirectory(_umgebung.Ordner.Pfad);
        var inhalt = _umgebung.Quelle.Inhalt;
        var setup = new SetupDatei(
            Versionsnummer.Lies("1.4.0")!,
            QuelleAttrappe.Adresse,
            inhalt.Length,
            SetupAuswahl.Sha256AusDigest(_umgebung.Quelle.RichtigerDigest)!);
        var pfad = Path.Combine(_umgebung.Ordner.Pfad, "probe.exe");

        SetupPruefung.Pruefe(pfad, setup).Should().Be(SetupPruefErgebnis.Fehlt);
        File.WriteAllBytes(pfad, inhalt);
        SetupPruefung.Pruefe(pfad, setup).Should().Be(SetupPruefErgebnis.InOrdnung);
        File.WriteAllBytes(pfad, inhalt[1..]);
        SetupPruefung.Pruefe(pfad, setup).Should().Be(SetupPruefErgebnis.GroesseFalsch);
        File.WriteAllBytes(pfad, [.. inhalt[1..], 0]);
        SetupPruefung.Pruefe(pfad, setup).Should().Be(SetupPruefErgebnis.PruefsummeFalsch);
    }
}
