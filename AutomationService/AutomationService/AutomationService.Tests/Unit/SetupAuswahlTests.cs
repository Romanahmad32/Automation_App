using AutomationService.Features.Aktualisierung.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Welche Datei am Release der Dienst herunterlädt und anschließend ausführt
/// (#196): nur der genaue Name, nur die Version des Tags, nur mit Größe und
/// <c>sha256</c>-Digest. Jeder Fall hier ist eine Datei, die er <b>nicht</b>
/// nehmen darf — oder der eine, den er nehmen muss.
/// </summary>
public sealed class SetupAuswahlTests
{
    private const string Laufend = "1.3.0+abc1234";
    private const string Digest = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    private const string Adresse = "https://github.com/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe";

    private static ReleaseDatei Setup(
        string name = "Automation_App_Setup_1.4.0.exe",
        long? groesse = 88_000_000,
        string? digest = Digest,
        string? adresse = Adresse) => new(name, groesse, digest, adresse);

    private static SetupAuswahlErgebnis Waehle(string tag, params ReleaseDatei[] dateien) =>
        SetupAuswahl.Waehle(new ReleaseBeschreibung(tag, dateien), Laufend);

    [Fact]
    public void Nimmt_die_Setup_Datei_der_Tag_Version_samt_Groesse_und_Pruefsumme()
    {
        var ergebnis = Waehle(
            "v1.4.0",
            new ReleaseDatei("Pruefsummen.txt", 100, Digest, "https://example.invalid/p.txt"),
            Setup());

        ergebnis.Art.Should().Be(AuswahlArt.Verfuegbar);
        ergebnis.NeueVersion!.ToString().Should().Be("1.4.0");
        ergebnis.Setup!.Groesse.Should().Be(88_000_000);
        ergebnis.Setup.Sha256.Should().Be(Digest["sha256:".Length..]);
        ergebnis.Setup.Adresse.AbsoluteUri.Should().Be(Adresse);
        ergebnis.DownloadUrl.Should().Be(Adresse);
    }

    [Theory]
    [InlineData("v1.3.0")]
    [InlineData("v1.2.9")]
    [InlineData("nightly")]
    [InlineData(null)]
    public void Nicht_neuer_oder_unlesbar_ist_kein_Update(string? tag)
    {
        Waehle(tag!, Setup()).Art.Should().Be(AuswahlArt.KeinUpdate);
    }

    [Fact]
    public void Ohne_lesbare_laufende_Version_gibt_es_kein_Update()
    {
        SetupAuswahl.Waehle(new ReleaseBeschreibung("v9.0.0", [Setup()]), "unbekannt")
            .Art.Should().Be(AuswahlArt.KeinUpdate);
    }

    [Theory]
    [InlineData("Automation_App_Setup_1.3.9.exe")]
    [InlineData("automation_app_setup_1.4.0.exe")]
    [InlineData("Automation_App_Setup_1.4.0.exe.sig")]
    [InlineData("Automation_App_Setup_1.4.0.zip")]
    [InlineData("x_Automation_App_Setup_1.4.0.exe")]
    [InlineData("Automation_App_Setup_v1.4.0.exe")]
    [InlineData("Automation_App_Setup_1.4.exe")]
    [InlineData("Automation_App_Setup_1.4.0.EXE")]
    [InlineData(" Automation_App_Setup_1.4.0.exe")]
    [InlineData("Automation_App_Setup_1.4.0.exe ")]
    [InlineData("Automation_App_Setup_1.4.0.exe\n")]
    [InlineData("Automation_App_Setup_١.4.0.exe")]
    [InlineData("Automation_App_Setup_1.4.0.1.exe")]
    [InlineData("Automation_App_Setup_1.4.0-beta.exe")]
    [InlineData("Automation_App_Setup_1.4.0.msi")]
    [InlineData("")]
    [InlineData(null)]
    public void Eine_Datei_mit_anderem_Namen_oder_anderer_Version_wird_nie_genommen(string? name)
    {
        var ergebnis = Waehle("v1.4.0", Setup(name!));

        ergebnis.Art.Should().Be(AuswahlArt.OhneSetup);
        ergebnis.NeueVersion!.ToString().Should().Be("1.4.0", "die neue Version ist trotzdem bekannt");
        ergebnis.Setup.Should().BeNull();
        ergebnis.DownloadUrl.Should().BeNull();
    }

    [Fact]
    public void Zwei_passende_Dateien_sind_mehrdeutig()
    {
        Waehle("v1.4.0", Setup(), Setup("Automation_App_Setup_01.4.0.exe")).Art.Should().Be(AuswahlArt.OhneSetup);
    }

    /// <summary>
    /// Hängt am Release noch die Setup-Datei einer anderen Version (etwa die
    /// alte, versehentlich mit hochgeladen), zählt nur die des Tags.
    /// </summary>
    [Fact]
    public void Neben_einer_Setup_Datei_anderer_Version_wird_die_des_Tags_genommen()
    {
        var ergebnis = Waehle(
            "1.4.0",
            Setup("Automation_App_Setup_1.3.0.exe", adresse: "https://example.invalid/alt.exe"),
            Setup());

        ergebnis.Art.Should().Be(AuswahlArt.Verfuegbar, "der Tag darf auch ohne „v“ stehen");
        ergebnis.Setup!.Adresse.AbsoluteUri.Should().Be(Adresse);
    }

    [Fact]
    public void Ohne_Dateiliste_gibt_es_keine_Setup_Datei()
    {
        SetupAuswahl.Waehle(new ReleaseBeschreibung("v1.4.0", null), Laufend).Art.Should().Be(AuswahlArt.OhneSetup);
    }

    [Theory]
    [InlineData("file:///C:/Temp/Automation_App_Setup_1.4.0.exe")]
    [InlineData("Automation_App_Setup_1.4.0.exe")]
    [InlineData(null)]
    public void Nur_eine_http_Adresse_wird_geladen(string? adresse)
    {
        Waehle("v1.4.0", Setup(adresse: adresse)).Art.Should().Be(AuswahlArt.OhneSetup);
    }

    /// <summary>
    /// <c>downloadUrl</c> landet im Browser des Anwalts. Was dort ankommt, soll
    /// nicht davon abhängen, was eine API-Antwort hineinschreibt — nur
    /// <c>https://github.com/…</c>. Laden darf der Dienst die Datei trotzdem:
    /// Er prüft Größe und Prüfsumme selbst.
    /// </summary>
    [Theory]
    [InlineData("http://github.com/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe")]
    [InlineData("https://objects.githubusercontent.com/github-production-release-asset/Automation_App_Setup_1.4.0.exe")]
    [InlineData("https://github.com.example.invalid/Automation_App_Setup_1.4.0.exe")]
    [InlineData("https://anwalt@github.com/Automation_App_Setup_1.4.0.exe")]
    [InlineData("https://github.com:8443/Automation_App_Setup_1.4.0.exe")]
    [InlineData("https://example.invalid/Automation_App_Setup_1.4.0.exe?x=github.com")]
    public void Nur_eine_https_Adresse_bei_github_com_geht_an_den_Browser(string adresse)
    {
        var ergebnis = Waehle("v1.4.0", Setup(adresse: adresse));
        var ohnePruefsumme = Waehle("v1.4.0", Setup(adresse: adresse, digest: null));

        ergebnis.Art.Should().Be(AuswahlArt.Verfuegbar);
        ergebnis.Setup!.Adresse.Should().Be(new Uri(adresse));
        ergebnis.DownloadUrl.Should().BeNull();
        ohnePruefsumme.DownloadUrl.Should().BeNull("auch der Rückfallweg ohne Prüfsumme nicht");
    }

    [Theory]
    [InlineData("https://github.com/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe")]
    [InlineData("https://GitHub.com/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe")]
    [InlineData("https://github.com:443/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe")]
    public void Die_Adresse_von_GitHub_geht_an_den_Browser(string adresse)
    {
        SetupAuswahl.FuerDenBrowser(new Uri(adresse)).Should().Be(Adresse);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("md5:0123456789abcdef0123456789abcdef")]
    [InlineData("sha256:0123")]
    [InlineData("sha256:zz23456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")]
    public void Ohne_gueltigen_Digest_wird_nicht_geladen_aber_der_Rueckfallweg_bleibt(string? digest)
    {
        var ergebnis = Waehle("v1.4.0", Setup(digest: digest));

        ergebnis.Art.Should().Be(AuswahlArt.OhnePruefsumme);
        ergebnis.Setup.Should().BeNull("eine Datei, die sich nicht prüfen lässt, lädt der Dienst nicht");
        ergebnis.DownloadUrl.Should().Be(Adresse, "„Lieber selbst herunterladen“ führt direkt auf die Datei");
    }

    [Theory]
    [InlineData(null)]
    [InlineData(0L)]
    [InlineData(-1L)]
    public void Ohne_Groesse_wird_nicht_geladen(long? groesse)
    {
        Waehle("v1.4.0", Setup(groesse: groesse)).Art.Should().Be(AuswahlArt.OhnePruefsumme);
    }

    [Fact]
    public void Der_Digest_wird_ohne_Ruecksicht_auf_Grossschreibung_gelesen()
    {
        SetupAuswahl.Sha256AusDigest("SHA256:" + new string('A', 64)).Should().Be(new string('a', 64));
    }
}
