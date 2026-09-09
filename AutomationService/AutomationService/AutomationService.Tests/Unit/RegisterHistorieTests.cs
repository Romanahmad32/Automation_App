using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Stand der Übernahme und das Nachführen einzelner Zeilen (§6.2).
///
/// Der Stand ist die eine Stelle, an der der Anwalt sieht, was noch fehlt —
/// deshalb muss er das Fehlende auch dann nennen, wenn niemand danach fragt:
/// ein Jahrgang, von dem keine einzige Zeile vorliegt, taucht in keiner
/// Gruppierung über den Bestand auf.
/// </summary>
public sealed class RegisterHistorieTests : IDisposable
{
    readonly RegisterImportAufbau _aufbau = new();

    [Fact]
    public async Task Stand_NenntZeilenLueckenUndHoechsteNummerJeJahrgang()
    {
        await _aufbau.Uebernimm(
            2019, RegisterImportAufbau.Zeile(1, jahr: "19"), RegisterImportAufbau.Zeile(3, jahr: "19"));

        var stand = await _aufbau.Historie.StandAsync();

        var jahrgang = stand.Jahrgaenge.Should().ContainSingle().Subject;
        jahrgang.Jahrgang.Should().Be(2019);
        jahrgang.Zeilen.Should().Be(2);
        jahrgang.HoechsteNummer.Should().Be(3);
        jahrgang.Luecken.Should().Equal(2);
        jahrgang.ZuletztImportiertAm.Should().NotBe(default);
    }

    /// <summary>
    /// Der Anwalt soll sehen, dass 2021 fehlt, <em>bevor</em> er 2022 einliest.
    /// Gezählt werden die Löcher <em>zwischen</em> dem kleinsten und dem
    /// größten übernommenen Jahrgang — kein festes Startjahr: Wie weit das
    /// Register zurückreicht, sagt der Bestand und keine Zahl im Code.
    /// </summary>
    [Fact]
    public async Task Stand_NenntNurDieLueckenZwischenDemKleinstenUndDemGroesstenJahrgang()
    {
        await _aufbau.Uebernimm(2019, RegisterImportAufbau.Zeile(1, jahr: "19"));
        await _aufbau.Uebernimm(2022, RegisterImportAufbau.Zeile(1, jahr: "22"));

        var stand = await _aufbau.Historie.StandAsync();

        stand.FehlendeJahrgaenge.Should().Equal(2020, 2021);
    }

    [Fact]
    public async Task Stand_MeldetOhneLueckeZwischenDenJahrgaengenNichtsFehlendes()
    {
        await _aufbau.Uebernimm(2019, RegisterImportAufbau.Zeile(1, jahr: "19"));
        await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(1));

        (await _aufbau.Historie.StandAsync()).FehlendeJahrgaenge.Should().BeEmpty();
    }

    [Fact]
    public async Task Stand_ZaehltDieZeilenMitBefund()
    {
        await _aufbau.Uebernimm(
            2020,
            RegisterImportAufbau.Zeile(1),
            RegisterImportAufbau.Zeile(2, abteilung: "C01a", rechtsgebiet: "Verkehrsrecht"));

        var stand = await _aufbau.Historie.StandAsync();

        stand.Jahrgaenge[0].MitBefund.Should().Be(1);
    }

    [Fact]
    public async Task Stand_IstOhneBestandLeer()
    {
        var stand = await _aufbau.Historie.StandAsync();

        stand.Jahrgaenge.Should().BeEmpty();
        stand.FehlendeJahrgaenge.Should().BeEmpty();
    }

    [Fact]
    public async Task GetAll_LiefertSortiertUndFiltertNachJahr()
    {
        await _aufbau.Uebernimm(
            new ImportJahrgang(2020, [RegisterImportAufbau.Zeile(2), RegisterImportAufbau.Zeile(1)]),
            new ImportJahrgang(2021, [RegisterImportAufbau.Zeile(1, jahr: "21")]));

        (await _aufbau.Historie.GetAllAsync(null))
            .Select(zeile => $"{zeile.Jahr}/{zeile.LaufendeNummer}")
            .Should().Equal("2020/1", "2020/2", "2021/1");

        (await _aufbau.Historie.GetAllAsync(2021)).Should().ContainSingle();
    }

    /// <summary>
    /// Was der Bearbeiten-Dialog beim Öffnen holt — mehr als die Ansicht zeigt:
    /// den Freitext als Beleg, die Befunde und die Hinweise des Erzeugers.
    /// </summary>
    [Fact]
    public async Task Get_LiefertDieZeileMitIhrenFeldern()
    {
        await _aufbau.Uebernimm(
            2019,
            RegisterImportAufbau.Zeile(
                10, nummerZusatz: "-I", abteilung: "C 02", rechtsgebiet: "Familienrecht",
                mandant: "Bernd Mustermann", gegner: "Beate Mustermann", sachbestand: "Ehescheidung",
                unfalldatum: "", sicherheit: "niedrig", hinweise: ["Nummer trägt den Zusatz -I"],
                jahr: "19"));
        var gespeichert = _aufbau.Gespeichert(2019, 10, "-I");

        var zeile = await _aufbau.Historie.GetAsync(gespeichert.Id);

        zeile.Should().NotBeNull();
        zeile!.Jahr.Should().Be(2019);
        zeile.LaufendeNummer.Should().Be(10);
        zeile.NummerZusatz.Should().Be("-I");
        zeile.Abteilung.Should().Be("C02", "das Kürzel wird ohne Leerzeichen geführt");
        zeile.Mandant.Should().Be("Bernd Mustermann");
        zeile.Gegner.Should().Be("Beate Mustermann");
        zeile.Sachbestand.Should().Be("Ehescheidung");
        zeile.Rechtsgebiet.Should().Be("Familienrecht");
        zeile.Sicherheit.Should().Be(RegisterSicherheiten.Niedrig);
        zeile.Kennung.Should().NotBeNullOrWhiteSpace();
        zeile.Freitext.Should().NotBeNullOrWhiteSpace("der Freitext ist der Beleg für jede Zerlegung");
        RegisterHistorieListen.Lies(zeile.HinweiseJson).Should().Equal("Nummer trägt den Zusatz -I");
        RegisterHistorieListen.Lies(zeile.BefundeJson).Should().Contain("Nummer trägt den Zusatz „-I“.");
        zeile.GeaendertAm.Should().BeNull("die Zeile ist frisch übernommen");
    }

    [Fact]
    public async Task Get_MeldetEineUnbekannteZeileAlsNull()
    {
        (await _aufbau.Historie.GetAsync(4711)).Should().BeNull();
    }

    /// <summary>
    /// Nach der Berichtigung muss der Befund weg sein. Bliebe er stehen, hielte
    /// die Zeile den Widerspruch fest, den der Anwalt gerade aufgelöst hat —
    /// und der Stand meldete auf ewig eine Zeile „mit Befund".
    /// </summary>
    [Fact]
    public async Task Aendere_SetztDieFelderUndRechnetDieBefundeNeu()
    {
        await _aufbau.Uebernimm(
            2023, RegisterImportAufbau.Zeile(16, abteilung: "C01a", rechtsgebiet: "Verkehrsrecht", jahr: "23"));
        var vorher = _aufbau.Gespeichert(2023, 16);
        RegisterHistorieListen.Lies(vorher.BefundeJson).Should().NotBeEmpty();

        var geaendert = await _aufbau.Historie.AendereAsync(vorher.Id, new RegisterHistorieAenderung(
            "C 01a", "", "Robert Mustermann", "Muster Personal", "KSch-Klage", "", "Arbeitsrecht"));

        geaendert.Should().NotBeNull();
        geaendert!.Abteilung.Should().Be("C01a", "das Kürzel wird ohne Leerzeichen geführt");
        geaendert.Rechtsgebiet.Should().Be("Arbeitsrecht");
        geaendert.GeaendertAm.Should().NotBeNull();
        RegisterHistorieListen.Lies(geaendert.BefundeJson).Should().BeEmpty();
    }

    [Fact]
    public async Task Aendere_MeldetEineUnbekannteZeileAlsNull()
    {
        var ergebnis = await _aufbau.Historie.AendereAsync(
            4711, new RegisterHistorieAenderung("C03", "", "", "", "", "", "Verkehrsrecht"));

        ergebnis.Should().BeNull();
    }

    public void Dispose() => _aufbau.Dispose();
}
