using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die fachlichen Regeln der Registerübernahme (§6.2): Vollständigkeit,
/// Widersprüche und die Zusicherung, dass die Datei nie überschreibt.
///
/// Der rote Faden aller Fälle ist derselbe: Der Bestand wird übernommen, wie er
/// ist, und was daran auffällt, wird benannt. Ein Test, der eine stillschweigend
/// berichtigte Zeile erwartet, wäre hier der Fehler.
/// </summary>
public sealed class RegisterImportTests : IDisposable
{
    readonly RegisterImportAufbau _aufbau = new();

    [Fact]
    public async Task Vorschau_NenntDieFehlendenNummernEinesJahrgangs()
    {
        var befund = await _aufbau.Vorschau(
            2020, RegisterImportAufbau.Zeile(1), RegisterImportAufbau.Zeile(4));

        befund.Jahrgaenge.Should().ContainSingle()
            .Which.Luecken.Should().Equal(2, 3);
    }

    [Fact]
    public async Task Vorschau_MeldetKeineLuecke_WennDieFolgeGeschlossenIst()
    {
        var befund = await _aufbau.Vorschau(
            2020, RegisterImportAufbau.Zeile(1), RegisterImportAufbau.Zeile(2));

        befund.Jahrgaenge.Should().ContainSingle().Which.Luecken.Should().BeEmpty();
    }

    /// <summary>
    /// Der zweite Lauf eines Jahrgangs darf die Nummern des ersten nicht als
    /// Lücke melden — sonst sähe eine Nachlieferung schlimmer aus als der
    /// Ausgangsstand.
    /// </summary>
    [Fact]
    public async Task Luecken_ZaehlenDenBestandMit()
    {
        await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(1), RegisterImportAufbau.Zeile(2));

        var befund = await _aufbau.Vorschau(2020, RegisterImportAufbau.Zeile(3));

        befund.Jahrgaenge.Should().ContainSingle().Which.Luecken.Should().BeEmpty();
    }

    [Fact]
    public async Task Eine_doppelte_Nummer_in_der_Datei_wird_beim_zweiten_Mal_abgelehnt()
    {
        var befund = await _aufbau.Vorschau(
            2020,
            RegisterImportAufbau.Zeile(1, mandant: "Max Mustermann"),
            RegisterImportAufbau.Zeile(1, mandant: "Erika Musterfrau"));

        var jahrgang = befund.Jahrgaenge.Should().ContainSingle().Subject;
        jahrgang.Doppelte.Should().Equal(1);
        jahrgang.Eintraege[0].Art.Should().Be(RegisterImportArten.Neu);
        jahrgang.Eintraege[1].Art.Should().Be(RegisterImportArten.Abgelehnt);
        jahrgang.Eintraege[1].Befunde.Should().ContainMatch("*doppelt*");
    }

    /// <summary>
    /// „10/19" und „10/19-I" sind zwei Akten des Bestands. Zählte der Zusatz
    /// nicht zum Schlüssel, verdrängte die eine die andere — und der Jahrgang
    /// verlöre eine Zeile, ohne dass es irgendwo aufschlüge.
    /// </summary>
    [Fact]
    public async Task Dieselbe_Nummer_mit_Zusatz_ist_eine_zweite_Akte_und_keine_Dublette()
    {
        var befund = await _aufbau.Uebernimm(
            2019,
            RegisterImportAufbau.Zeile(10, jahr: "19"),
            RegisterImportAufbau.Zeile(10, nummerZusatz: "-I", jahr: "19"));

        var jahrgang = befund.Jahrgaenge.Should().ContainSingle().Subject;
        jahrgang.Doppelte.Should().BeEmpty();
        jahrgang.Neu.Should().Be(2);
        jahrgang.Abgelehnt.Should().Be(0);
        _aufbau.Gespeichert(2019, 10).NummerZusatz.Should().BeEmpty();
        _aufbau.Gespeichert(2019, 10, "-I").NummerZusatz.Should().Be("-I");
        // Beide belegen dieselbe Stelle der Nummernfolge.
        jahrgang.Luecken.Should().Equal(1, 2, 3, 4, 5, 6, 7, 8, 9);
    }

    /// <summary>
    /// Ein inhaltlicher Befund lehnt nie ab. Der Bestand hat Zeilen, die aus
    /// jedem Schema fallen — eine App, die sie abweist, führt ein Register, das
    /// es so nie gab.
    /// </summary>
    [Fact]
    public async Task Eine_Zeile_ohne_laufende_Nummer_wird_uebernommen_und_benannt()
    {
        var befund = await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(0));

        var eintrag = befund.Jahrgaenge[0].Eintraege[0];
        eintrag.Art.Should().Be(RegisterImportArten.Neu);
        eintrag.Befunde.Should().Contain("Ohne laufende Nummer — die Zeile steht außerhalb der Nummernfolge.");
        _aufbau.Db.RegisterHistorie.Should().ContainSingle();
    }

    /// <summary>
    /// Zwei Zeilen ohne laufende Nummer sind <b>keine</b> Dublette — anders als
    /// bei einer echten Nummer gibt es zwischen ihnen keinen Schlüssel, über den
    /// sie kollidieren könnten. Vor der Korrektur bekamen beide denselben
    /// Platzhalter (0, "") und die zweite wurde fälschlich als „Doppelnummer 0"
    /// abgelehnt.
    /// </summary>
    [Fact]
    public async Task Zwei_Zeilen_ohne_laufende_Nummer_werden_beide_als_neu_uebernommen()
    {
        var befund = await _aufbau.Uebernimm(
            2020,
            RegisterImportAufbau.Zeile(0, mandant: "Max Mustermann"),
            RegisterImportAufbau.Zeile(0, mandant: "Erika Musterfrau"));

        var jahrgang = befund.Jahrgaenge.Should().ContainSingle().Subject;
        jahrgang.Doppelte.Should().BeEmpty();
        jahrgang.Neu.Should().Be(2);
        jahrgang.Abgelehnt.Should().Be(0);
        jahrgang.Eintraege.Should().OnlyContain(eintrag => eintrag.Art == RegisterImportArten.Neu);
        _aufbau.Db.RegisterHistorie.Should().HaveCount(2);
    }

    /// <summary>
    /// Ohne Nummer fehlt der natürliche Schlüssel, an dem ein zweiter Lauf eine
    /// schon übernommene Zeile sonst erkennt (§6.2 „ein zweiter Lauf lässt alles
    /// stehen"). Ersatzweise wird über Zusatz und Freitext wiedererkannt — sonst
    /// legte das versehentliche zweite Einlesen desselben Jahrgangs dieselbe
    /// nummernlose Zeile ein zweites Mal an.
    /// </summary>
    [Fact]
    public async Task Eine_Zeile_ohne_laufende_Nummer_wird_bei_erneutem_Einlesen_wiedererkannt()
    {
        await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(0, mandant: "Max Mustermann"));

        var befund = await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(0, mandant: "Max Mustermann"));

        var jahrgang = befund.Jahrgaenge.Should().ContainSingle().Subject;
        jahrgang.Neu.Should().Be(0);
        jahrgang.Unveraendert.Should().Be(1);
        _aufbau.Db.RegisterHistorie.Should().ContainSingle();
    }

    [Fact]
    public async Task Spalte1_die_der_Nummer_widerspricht_wird_an_der_Zeile_gemeldet()
    {
        var befund = await _aufbau.Vorschau(2022, RegisterImportAufbau.Zeile(13, spalte1: "12", jahr: "22"));

        befund.Jahrgaenge[0].Eintraege[0].Befunde.Should()
            .ContainSingle().Which.Should().Be("Spalte 1 „12“ widerspricht der Nummer im Aktenzeichen „13/22“.");
    }

    /// <summary>
    /// Der Fall aus dem Bestand: eine Arbeitsrechtssache, deren Spalte 3
    /// „Verkehrsrecht" sagt. Übernommen wird, was in der Datei steht — die
    /// Bereinigung ist Sache des Anwalts, nicht des Imports.
    /// </summary>
    [Fact]
    public async Task Abteilung_die_dem_Rechtsgebiet_widerspricht_wird_gemeldet_und_trotzdem_uebernommen()
    {
        var befund = await _aufbau.Uebernimm(
            2023, RegisterImportAufbau.Zeile(16, abteilung: "C01a", rechtsgebiet: "Verkehrsrecht", jahr: "23"));

        var eintrag = befund.Jahrgaenge[0].Eintraege[0];
        befund.Jahrgaenge[0].Abweichungen.Should().Be(1);
        eintrag.Art.Should().Be(RegisterImportArten.Neu);
        eintrag.Befunde.Should().ContainMatch("Abteilung C01a (Arbeitsrecht) widerspricht Spalte 3*");

        var gespeichert = _aufbau.Gespeichert(2023, 16);
        gespeichert.Abteilung.Should().Be("C01a");
        gespeichert.Rechtsgebiet.Should().Be("Verkehrsrecht", "die Datei wird nicht berichtigt");
    }

    /// <summary>
    /// „C05/3" ist Strafrecht mit Verkehrsbezug. Das Nebensachgebiet zählt beim
    /// Abgleich mit — sonst meldete jede Verkehrsstrafsache des Bestands einen
    /// Widerspruch, den es nicht gibt.
    /// </summary>
    [Fact]
    public async Task Ein_Nebensachgebiet_deckt_das_Rechtsgebiet_ebenfalls_ab()
    {
        var befund = await _aufbau.Vorschau(
            2025, RegisterImportAufbau.Zeile(10, abteilung: "C05/3", rechtsgebiet: "Verkehrsrecht", jahr: "25"));

        befund.Jahrgaenge[0].Abweichungen.Should().Be(0);
        befund.Jahrgaenge[0].Eintraege[0].Befunde.Should().BeEmpty();
    }

    /// <summary>
    /// „Vertragsrecht" hatte nie ein Kürzel und steht deshalb bewusst nicht im
    /// Katalog. Das ist ein Hinweis und kein Mangel: Die Zeile wird übernommen,
    /// sie kommt nur auf die Prüfliste.
    /// </summary>
    [Fact]
    public async Task Ein_Rechtsgebiet_ausserhalb_des_Katalogs_ist_ein_Hinweis_und_kein_Grund_zur_Ablehnung()
    {
        var befund = await _aufbau.Vorschau(
            2020, RegisterImportAufbau.Zeile(16, abteilung: "C01", rechtsgebiet: "Vertragsrecht"));

        var eintrag = befund.Jahrgaenge[0].Eintraege[0];
        eintrag.Art.Should().Be(RegisterImportArten.Neu);
        eintrag.ZuPruefen.Should().BeTrue();
        eintrag.Befunde.Should()
            .ContainSingle().Which.Should().Be("Rechtsgebiet „Vertragsrecht“ steht nicht im Sachgebietskatalog.");
        befund.Jahrgaenge[0].Abweichungen.Should().Be(0);
    }

    [Fact]
    public async Task Eine_unbekannte_Abteilung_wird_benannt()
    {
        var befund = await _aufbau.Vorschau(2020, RegisterImportAufbau.Zeile(1, abteilung: "C09"));

        befund.Jahrgaenge[0].Eintraege[0].Befunde.Should()
            .Contain("Abteilung „C09“ ist im Sachgebietskatalog unbekannt.");
    }

    [Fact]
    public async Task Eine_Zeile_ohne_Abteilung_wird_benannt()
    {
        var befund = await _aufbau.Vorschau(2018, RegisterImportAufbau.Zeile(1, abteilung: "", jahr: "18"));

        befund.Jahrgaenge[0].Eintraege[0].Befunde.Should().Contain("Ohne Abteilung.");
    }

    [Fact]
    public async Task Ein_Nummernzusatz_kommt_dem_Anwalt_vor_Augen()
    {
        var befund = await _aufbau.Vorschau(
            2019, RegisterImportAufbau.Zeile(10, nummerZusatz: "-I", jahr: "19"));

        befund.Jahrgaenge[0].Eintraege[0].Befunde.Should().Contain("Nummer trägt den Zusatz „-I“.");
    }

    [Fact]
    public async Task Die_Vorschau_schreibt_nichts()
    {
        var befund = await _aufbau.Vorschau(2020, RegisterImportAufbau.Zeile(1));

        befund.Angewendet.Should().BeFalse();
        _aufbau.Db.RegisterHistorie.Should().BeEmpty();
    }

    [Fact]
    public async Task Das_Uebernehmen_legt_die_Zeilen_an()
    {
        var befund = await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(1), RegisterImportAufbau.Zeile(2));

        befund.Angewendet.Should().BeTrue();
        befund.Jahrgaenge[0].Neu.Should().Be(2);
        _aufbau.Db.RegisterHistorie.Should().HaveCount(2);
        _aufbau.Gespeichert(2020, 1).Kennung.Should().NotBeNullOrWhiteSpace();
        _aufbau.Gespeichert(2020, 1).Quelle.Should().Be(RegisterHistorieEntity.QuelleImport);
    }

    /// <summary>
    /// Der wichtigste Fall des ganzen Imports: Der Anwalt liest denselben
    /// Jahrgang versehentlich ein zweites Mal ein. Nichts darf verlorengehen —
    /// weder der zugeordnete Mandant noch eine von Hand berichtigte Spalte.
    /// </summary>
    [Fact]
    public async Task Ein_zweiter_Lauf_desselben_Jahrgangs_laesst_alles_stehen()
    {
        await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(1, mandant: "Max Mustermann"));

        var zeile = _aufbau.Db.RegisterHistorie.Single();
        zeile.MandantId = 42;
        await _aufbau.Db.SaveChangesAsync();
        await _aufbau.Historie.AendereAsync(zeile.Id, new RegisterHistorieAenderung(
            "C03", "", "Maximilian Mustermann", "HUK", "Unfall", "01.01.20", "Verkehrsrecht"));

        var befund = await _aufbau.Uebernimm(2020, RegisterImportAufbau.Zeile(1, mandant: "Max Mustermann"));

        befund.Jahrgaenge[0].Unveraendert.Should().Be(1);
        befund.Jahrgaenge[0].Neu.Should().Be(0);
        _aufbau.Db.RegisterHistorie.Should().ContainSingle();

        var nachher = _aufbau.Gespeichert(2020, 1);
        nachher.MandantId.Should().Be(42);
        nachher.Mandant.Should().Be("Maximilian Mustermann", "die Datei überschreibt nie");
        nachher.GeaendertAm.Should().NotBeNull();
    }

    [Fact]
    public async Task Mehrere_Jahrgaenge_in_einer_Datei_werden_je_fuer_sich_geprueft()
    {
        var befund = await _aufbau.Uebernimm(
            new ImportJahrgang(2019, [RegisterImportAufbau.Zeile(1, jahr: "19")]),
            new ImportJahrgang(2020, [RegisterImportAufbau.Zeile(2)]));

        befund.Jahrgaenge.Select(jahrgang => jahrgang.Jahrgang).Should().Equal(2019, 2020);
        befund.Jahrgaenge[1].Luecken.Should().Equal(1);
    }

    /// <summary>
    /// Die Zeilennummer zählt je Jahrgang von 1 an und läuft nicht über die
    /// Datei durch: Die Oberfläche spricht eine Zeile als (Jahrgang, Zeile) an,
    /// und in der Befundkarte eines Jahrgangs wäre eine dateiweite Nummer eine
    /// Zahl ohne Bezug.
    /// </summary>
    [Fact]
    public async Task Die_Zeilennummer_beginnt_in_jedem_Jahrgang_wieder_bei_eins()
    {
        var befund = await _aufbau.Uebernimm(
            new ImportJahrgang(2019,
                [RegisterImportAufbau.Zeile(1, jahr: "19"), RegisterImportAufbau.Zeile(2, jahr: "19")]),
            new ImportJahrgang(2020,
                [RegisterImportAufbau.Zeile(1), RegisterImportAufbau.Zeile(2)]));

        befund.Jahrgaenge[0].Eintraege.Select(eintrag => eintrag.Zeile).Should().Equal(1, 2);
        befund.Jahrgaenge[1].Eintraege.Select(eintrag => eintrag.Zeile).Should().Equal(1, 2);
        befund.Jahrgaenge[1].Eintraege.Should().OnlyContain(eintrag => eintrag.Jahrgang == 2020);
    }

    public void Dispose() => _aufbau.Dispose();
}
