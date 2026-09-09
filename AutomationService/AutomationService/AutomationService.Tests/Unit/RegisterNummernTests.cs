using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Nummernvergabe (§6.3): Vorschlag = höchste belegte Nummer + 1,
/// quellenübergreifend über Vorgänge und übernommene Historie, Lücken bleiben
/// Lücken.
/// </summary>
public sealed class RegisterNummernTests
{
    static RegisterZeile Zeile(string jahr, int? nummer, string quelle) => new(
        Jahr: jahr,
        LaufendeNummer: nummer,
        Zeichen: "1/26 C03",
        Parteien: "Mustermann ./. HUK",
        Sachbestand: "Sachverhalt v. 28.12.2025",
        Rechtsgebiet: "Verkehrsrecht",
        Abgeschlossen: true,
        Quelle: quelle);

    [Fact]
    public void Stand_SchlaegtBeiLeeremJahrgangDieEinsVor()
    {
        var stand = RegisterNummern.Stand([], "2026");

        stand.Jahr.Should().Be("2026");
        stand.HoechsteNummer.Should().Be(0);
        stand.NaechsteNummer.Should().Be(1);
        stand.Belegte.Should().BeEmpty();
    }

    [Fact]
    public void Stand_RechnetNurMitDerHistorie()
    {
        var zeilen = new[]
        {
            Zeile("2026", 3, RegisterQuellen.Historie),
            Zeile("2026", 7, RegisterQuellen.Historie),
        };

        var stand = RegisterNummern.Stand(zeilen, "2026");

        stand.HoechsteNummer.Should().Be(7);
        stand.NaechsteNummer.Should().Be(8);
        stand.Belegte.Should().Equal(3, 7);
    }

    [Fact]
    public void Stand_RechnetNurMitDenVorgaengen()
    {
        var zeilen = new[]
        {
            Zeile("2026", 1, RegisterQuellen.Vorgang),
            Zeile("2026", 4, RegisterQuellen.Vorgang),
        };

        var stand = RegisterNummern.Stand(zeilen, "2026");

        stand.HoechsteNummer.Should().Be(4);
        stand.NaechsteNummer.Should().Be(5);
        stand.Belegte.Should().Equal(1, 4);
    }

    [Fact]
    public void Stand_MischtVorgaengeUndHistorieQuellenuebergreifend()
    {
        var zeilen = new[]
        {
            Zeile("2026", 1, RegisterQuellen.Vorgang),
            Zeile("2026", 5, RegisterQuellen.Historie),
            Zeile("2026", 3, RegisterQuellen.Vorgang),
        };

        var stand = RegisterNummern.Stand(zeilen, "2026");

        stand.HoechsteNummer.Should().Be(5);
        stand.NaechsteNummer.Should().Be(6);
        stand.Belegte.Should().Equal(1, 3, 5);
    }

    /// <summary>
    /// Ein noch nicht abgeschlossener Vorgang kann eine laufende Nummer haben
    /// oder nicht — ohne zählt er nicht als belegte <c>0</c>.
    /// </summary>
    [Fact]
    public void Stand_UeberspringtZeilenOhneLaufendeNummer()
    {
        var zeilen = new[]
        {
            Zeile("2026", null, RegisterQuellen.Vorgang),
            Zeile("2026", 2, RegisterQuellen.Vorgang),
        };

        var stand = RegisterNummern.Stand(zeilen, "2026");

        stand.HoechsteNummer.Should().Be(2);
        stand.NaechsteNummer.Should().Be(3);
        stand.Belegte.Should().Equal(2);
    }

    /// <summary>
    /// Der gewachsene Bestand kennt echte Doubletten (§6.2) — <c>1/26</c> und
    /// <c>5/26</c> sind heute jeweils zweimal vergeben. Die Liste der
    /// belegten Nummern führt jede trotzdem nur einmal.
    /// </summary>
    [Fact]
    public void Stand_FuehrtEineDoppelteNummerNurEinmalAlsBelegt()
    {
        var zeilen = new[]
        {
            Zeile("2026", 1, RegisterQuellen.Vorgang),
            Zeile("2026", 1, RegisterQuellen.Historie),
            Zeile("2026", 5, RegisterQuellen.Vorgang),
            Zeile("2026", 5, RegisterQuellen.Historie),
        };

        var stand = RegisterNummern.Stand(zeilen, "2026");

        stand.Belegte.Should().Equal(1, 5);
        stand.HoechsteNummer.Should().Be(5);
        stand.NaechsteNummer.Should().Be(6);
    }

    /// <summary>
    /// Ausdrücklich <em>nicht</em> die kleinste freie Nummer: Im Bestand
    /// fehlen hier 3 und 4, die Lücke bleibt Lücke — der Vorschlag ist die
    /// höchste belegte + 1.
    /// </summary>
    [Fact]
    public void Stand_FuelltEineLueckeNichtAuf()
    {
        var zeilen = new[]
        {
            Zeile("2026", 1, RegisterQuellen.Vorgang),
            Zeile("2026", 2, RegisterQuellen.Vorgang),
            Zeile("2026", 5, RegisterQuellen.Vorgang),
        };

        var stand = RegisterNummern.Stand(zeilen, "2026");

        stand.NaechsteNummer.Should().Be(6);
        stand.Belegte.Should().Equal(1, 2, 5);
    }

    [Fact]
    public void Stand_LaesstEinenAnderenJahrgangUnberuehrt()
    {
        var zeilen = new[]
        {
            Zeile("2025", 9, RegisterQuellen.Vorgang),
            Zeile("2026", 1, RegisterQuellen.Vorgang),
        };

        var stand = RegisterNummern.Stand(zeilen, "2026");

        stand.HoechsteNummer.Should().Be(1);
        stand.NaechsteNummer.Should().Be(2);
        stand.Belegte.Should().Equal(1);
    }
}
