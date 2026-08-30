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
            Abgeschlossen: true));
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
}
