using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die fachlichen Regeln des Registers (§6.2): welche Zeile hineinkommt,
/// unter welchem Jahrgang sie steht und in welcher Reihenfolge.
///
/// Die Jahrgangsregel hat ein echtes Vorbild: In der gewachsenen Kanzleidatei
/// fehlt ab 2025 die Jahresüberschrift. Der Export soll diese Lücke nicht
/// erben, also muss ein Jahrgang auch ohne das Feld herauskommen.
/// </summary>
public sealed class RegisterZeilenBauTests
{
    static VorgangEntity Vorgang(
        string referenz,
        string status = "versendet",
        int? nummer = 1,
        string? jahr = "26",
        string? abteilung = "C03",
        DateTime? angefragt = null) => new()
        {
            Referenz = referenz,
            Status = status,
            Rechtsgebiet = "verkehrsrecht",
            LaufendeNummer = nummer,
            Jahr = jahr,
            Abteilung = abteilung,
            MandantName = "Mustermann",
            Gegner = "HUK",
            UnfallDatum = "28.12.2025",
            AngefragtAm = angefragt ?? new DateTime(2026, 1, 5),
        };

    /// <summary>
    /// Ohne eingetragenen Gegner tritt der Versicherer aus der
    /// Zentralruf-Antwort an seine Stelle — wie in der Ansicht
    /// (<c>Vorgang.parteienBezeichnung</c>). Sonst stünde in der Datei
    /// „Mustermann ./." mit hängendem Trenner, während der Bildschirm daneben
    /// den Versicherer zeigt.
    /// </summary>
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Aus_NimmtDenVersichererAusDerAntwort_WennKeinGegnerEingetragenIst(string? gegner)
    {
        var vorgang = Vorgang("01/26 C03_HG-E 1427");
        vorgang.Gegner = gegner;
        vorgang.AntwortJson = """{"versichererName":"HUK-COBURG","kennzeichen":"HG-E 1427"}""";

        var zeile = RegisterZeilenBau.Aus([vorgang], nurAbgeschlossene: false).Should().ContainSingle().Subject;

        zeile.Parteien.Should().Be("Mustermann ./. HUK-COBURG");
    }

    [Fact]
    public void Aus_LaesstDemEingetragenenGegnerDenVortritt()
    {
        var vorgang = Vorgang("01/26 C03_HG-E 1427");
        vorgang.AntwortJson = """{"versichererName":"HUK-COBURG"}""";

        var zeile = RegisterZeilenBau.Aus([vorgang], nurAbgeschlossene: false).Should().ContainSingle().Subject;

        zeile.Parteien.Should().Be("Mustermann ./. HUK");
    }

    /// <summary>
    /// AntwortJson ist für das Backend ein opakes Feld. Ein kaputter Satz darf
    /// den Registerauszug nicht verhindern — eine Lücke in einer Zelle ist die
    /// bessere Antwort als eine Datei, die gar nicht entsteht.
    /// </summary>
    [Theory]
    [InlineData("kein json")]
    [InlineData("[]")]
    [InlineData("""{"versichererName":42}""")]
    public void Aus_KommtMitUnbrauchbaremAntwortJsonAus(string antwortJson)
    {
        var vorgang = Vorgang("01/26 C03_HG-E 1427");
        vorgang.Gegner = null;
        vorgang.AntwortJson = antwortJson;

        var zeile = RegisterZeilenBau.Aus([vorgang], nurAbgeschlossene: false).Should().ContainSingle().Subject;

        zeile.Parteien.Should().Be("Mustermann ./.");
    }

    [Fact]
    public void Aus_SetztDasSpaltenschemaZusammen()
    {
        var zeilen = RegisterZeilenBau.Aus([Vorgang("01/26 C03_HG-E 1427")], nurAbgeschlossene: false);

        zeilen.Should().ContainSingle().Which.Should().BeEquivalentTo(new RegisterZeile(
            Jahr: "2026",
            LaufendeNummer: 1,
            Zeichen: "1/26 C03",
            Parteien: "Mustermann ./. HUK",
            Sachbestand: "Sachverhalt v. 28.12.2025",
            Rechtsgebiet: "Verkehrsrecht",
            Abgeschlossen: true,
            VorgangReferenz: "01/26 C03_HG-E 1427"));
    }

    [Fact]
    public void Aus_NimmtOhneFilterAuchNichtAbgeschlosseneAuf()
    {
        var zeilen = RegisterZeilenBau.Aus(
            [Vorgang("01/26 C03", status: "versendet"), Vorgang("02/26 C03", status: "angefragt", nummer: 2)],
            nurAbgeschlossene: false);

        zeilen.Should().HaveCount(2);
        zeilen.Should().ContainSingle(z => !z.Abgeschlossen);
    }

    [Fact]
    public void Aus_LaesstMitFilterNurAbgeschlosseneUebrig()
    {
        var zeilen = RegisterZeilenBau.Aus(
            [Vorgang("01/26 C03", status: "versendet"), Vorgang("02/26 C03", status: "abgelegt", nummer: 2)],
            nurAbgeschlossene: true);

        zeilen.Should().ContainSingle().Which.Abgeschlossen.Should().BeTrue();
    }

    [Fact]
    public void Jahrgang_MachtAusZweistelligemJahrDieUeberschrift()
    {
        RegisterZeilenBau.Jahrgang(Vorgang("01/26 C03", jahr: "26")).Should().Be("2026");
    }

    /// <summary>
    /// Was <em>keine</em> Jahreszahl ist, fällt auf das Datum zurück — und zwar
    /// genau das, was auch das Frontend ablehnt. „-1" wurde dort von
    /// <c>int.tryParse</c> angenommen und ergab den Jahrgang „20-1"; Ziffern
    /// anderer Schriften nahm hier <c>char.IsDigit</c> an und ergab „20٢٦".
    /// Beide Seiten zeigten dann verschiedene Jahrgänge auf denselben Vorgang.
    /// Das Gegenstück steht in <c>vorgang_jahrgang_test.dart</c>.
    /// </summary>
    [Theory]
    [InlineData("-1")]
    [InlineData("+1")]
    [InlineData("٢٦")]
    [InlineData("2o")]
    public void Jahrgang_NimmtNurZiffern(string jahr)
    {
        var vorgang = Vorgang("01/26 C03", jahr: jahr, angefragt: new DateTime(2024, 3, 7));

        RegisterZeilenBau.Jahrgang(vorgang).Should().Be("2024");
    }

    [Fact]
    public void Jahrgang_FaelltOhneJahresfeldAufDasDatumZurueck()
    {
        var ohneJahr = Vorgang("frei erfasst", jahr: null, nummer: null, abteilung: null,
            angefragt: new DateTime(2024, 3, 7));

        RegisterZeilenBau.Jahrgang(ohneJahr).Should().Be("2024");
    }

    [Fact]
    public void Jahrgang_ZaehltZumAbschlussjahr_WennDerVorgangJahresuebergreifendLief()
    {
        var vorgang = Vorgang("01/26 C03", jahr: null, nummer: null, abteilung: null,
            angefragt: new DateTime(2025, 12, 30));
        vorgang.AbgeschlossenAm = new DateTime(2026, 1, 8);

        RegisterZeilenBau.Jahrgang(vorgang).Should().Be("2026");
    }

    [Fact]
    public void Aus_SortiertNachJahrgangUndLaufenderNummer()
    {
        var zeilen = RegisterZeilenBau.Aus(
            [
                Vorgang("02/26 C03", nummer: 2, jahr: "26"),
                Vorgang("07/25 C03", nummer: 7, jahr: "25"),
                Vorgang("01/26 C03", nummer: 1, jahr: "26"),
            ],
            nurAbgeschlossene: false);

        zeilen.Select(z => $"{z.Jahr}/{z.LaufendeNummer}")
            .Should().Equal("2025/7", "2026/1", "2026/2");
    }

    /// <summary>
    /// Ohne Nummer ans Ende des Jahrgangs: Sie wird erst beim Abschluss
    /// vergeben, und eine Zeile, die vorher irgendwo dazwischen stünde, würfe
    /// beim Abschluss die halbe Datei um.
    /// </summary>
    [Fact]
    public void Aus_HaengtZeilenOhneNummerHintenAn()
    {
        var zeilen = RegisterZeilenBau.Aus(
            [
                Vorgang("offen", status: "angefragt", nummer: null, jahr: "26", abteilung: null),
                Vorgang("09/26 C03", nummer: 9, jahr: "26"),
            ],
            nurAbgeschlossene: false);

        zeilen.Select(z => z.LaufendeNummer).Should().Equal(9, null);
    }

    static RegisterHistorieEntity Historisch(
        int jahr,
        int nummer,
        string nummerZusatz = "",
        string abteilung = "C03",
        string sachart = "",
        string gegner = "Allianz") => new()
        {
            Kennung = $"{jahr}-{nummer}",
            Id = jahr * 100 + nummer,
            Jahr = jahr,
            LaufendeNummer = nummer,
            NummerZusatz = nummerZusatz,
            Aktenzeichen = $"{nummer:00}/{jahr % 100:00}{nummerZusatz}",
            Abteilung = abteilung,
            AbteilungRoh = abteilung,
            Sachart = sachart,
            Mandant = "Anna Musterfrau",
            Gegner = gegner,
            Sachbestand = "Unfall",
            Unfalldatum = "28.12.18",
            Rechtsgebiet = "Verkehrsrecht",
            Sicherheit = "hoch",
            ImportiertAm = new DateTime(2026, 1, 5),
        };

    /// <summary>
    /// Beide Quellen in <em>einer</em> Folge — nicht Historie als Block vor den
    /// Vorgängen. Nur so steht eine übernommene Zeile an ihrer Nummer, und nur
    /// so sagen Bildschirm und Spiegeldatei per Konstruktion dasselbe.
    /// </summary>
    [Fact]
    public void Aus_MischtBeideQuellenNachJahrgangUndNummer()
    {
        var zeilen = RegisterZeilenBau.Aus(
            [Vorgang("02/26 C03", nummer: 2, jahr: "26"), Vorgang("01/19 C03", nummer: 1, jahr: "19")],
            [Historisch(2019, 3), Historisch(2026, 1)],
            nurAbgeschlossene: false);

        zeilen.Select(z => $"{z.Jahr}/{z.LaufendeNummer}")
            .Should().Equal("2019/1", "2019/3", "2026/1", "2026/2");
        zeilen.Select(z => z.Quelle)
            .Should().Equal(RegisterQuellen.Vorgang, RegisterQuellen.Historie,
                RegisterQuellen.Historie, RegisterQuellen.Vorgang);
    }

    [Fact]
    public void Aus_SetztDasSpaltenschemaEinerHistorischenZeileZusammen()
    {
        var zeile = RegisterZeilenBau
            .Aus([], [Historisch(2019, 10, nummerZusatz: "-I", abteilung: "C02")], nurAbgeschlossene: true)
            .Should().ContainSingle().Subject;

        zeile.Zeichen.Should().Be("10/19-I C02");
        zeile.Parteien.Should().Be("Anna Musterfrau ./. Allianz");
        zeile.Sachbestand.Should().Be("Unfall v. 28.12.18");
        zeile.Abgeschlossen.Should().BeTrue();
        zeile.HistorieId.Should().Be(201910);
        zeile.VorgangReferenz.Should().BeNull();
    }

    /// <summary>Form B des Bestands: Sachart vor dem Namen, keine Gegenseite.</summary>
    [Fact]
    public void Aus_SchreibtFormBOhneTrenner()
    {
        var zeile = RegisterZeilenBau
            .Aus([], [Historisch(2019, 13, abteilung: "C03o", sachart: "Bußgeldsache", gegner: "")], false)
            .Should().ContainSingle().Subject;

        zeile.Parteien.Should().Be("Bußgeldsache Anna Musterfrau");
    }

    /// <summary>
    /// Der Dateifilter greift nur an den Vorgängen: Eine übernommene Zeile
    /// stammt aus dem Register der erledigten Jahre und fällt unter keinen.
    /// </summary>
    [Fact]
    public void Aus_LaesstHistorischeZeilenAuchDurchDenFilter()
    {
        var zeilen = RegisterZeilenBau.Aus(
            [Vorgang("04/26 C03", status: "angefragt", nummer: 4)],
            [Historisch(2019, 1)],
            nurAbgeschlossene: true);

        zeilen.Should().ContainSingle().Which.Quelle.Should().Be(RegisterQuellen.Historie);
    }

    [Fact]
    public void Aus_TraegtDieReferenzDesVorgangsInDieZeile()
    {
        var zeile = RegisterZeilenBau
            .Aus([Vorgang("01/26 C03_HG-E 1427")], nurAbgeschlossene: false)
            .Should().ContainSingle().Subject;

        zeile.Quelle.Should().Be(RegisterQuellen.Vorgang);
        zeile.VorgangReferenz.Should().Be("01/26 C03_HG-E 1427");
        zeile.HistorieId.Should().BeNull();
    }
}
