using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Das Buch über die Arbeitspakete. Ein Bestand von rund 4000 Ordnern wird in
/// Paketen von etwa 200 bearbeitet, und dabei kommt es auf zwei Zusagen an:
/// die Reihenfolge ist stabil (dasselbe Paket, solange nichts eingelesen wurde;
/// ein abgebrochenes steht wieder vorn), und ein Ordner erscheint nie in zwei
/// Paketen, wenn dazwischen eingelesen wurde. Beides ist von außen nicht zu
/// sehen — wer es nicht prüft, merkt den Bruch erst, wenn hundert Ordner
/// zweimal bearbeitet oder gar nicht bearbeitet wurden.
///
/// Alle Namen hier sind erfunden: Arbeitspakete tragen Mandantennamen, und die
/// gehören nicht ins Repository.
/// </summary>
public sealed class ArbeitspaketBuchTests : IDisposable
{
    static readonly string[] Bestand =
    [
        "VUnfallursache Adler",
        "VUnfallursache Berger",
        "VUnfallursache Cramer",
        "VUnfallursache Dorn",
        "VUnfallursache Esch",
    ];

    readonly MandantenImportAufbau _aufbau = new();

    public void Dispose() => _aufbau.Dispose();

    // Der Erzeuger bricht ab, die Sitzung ist zu Ende, am nächsten Tag holt
    // jemand erneut ein Paket: es muss dasselbe sein, sonst bliebe der Rest des
    // abgebrochenen liegen, ohne dass es jemandem auffiele.
    [Fact]
    public async Task Zwei_Pakete_ohne_Import_dazwischen_enthalten_dieselben_Ordner()
    {
        var erstes = await _aufbau.Buch.HoleAsync(Bestand, 2);
        var zweites = await _aufbau.Buch.HoleAsync(Bestand, 2);

        MandantenImportAufbau.Ordner(erstes).Should()
            .Equal("VUnfallursache Adler", "VUnfallursache Berger");
        MandantenImportAufbau.Ordner(zweites).Should()
            .Equal(MandantenImportAufbau.Ordner(erstes));
        erstes.Nummer.Should().Be(1);
        zweites.Nummer.Should().Be(2, "geholt wurde zweimal, und beides steht im Buch");
    }

    [Fact]
    public async Task Nach_dem_Import_liefert_das_naechste_Paket_die_naechsten_Ordner()
    {
        await _aufbau.Buch.HoleAsync(Bestand, 2);

        await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile("Anna", "Adler", ["VUnfallursache Adler"]),
            MandantenImportAufbau.Zeile("Bernd", "Berger", ["VUnfallursache Berger"]),
        ]);
        var zweites = await _aufbau.Buch.HoleAsync(Bestand, 2);

        MandantenImportAufbau.Ordner(zweites).Should()
            .Equal("VUnfallursache Cramer", "VUnfallursache Dorn");
    }

    [Fact]
    public async Task Ein_Ordner_erscheint_nie_in_zwei_Paketen_wenn_dazwischen_eingelesen_wurde()
    {
        var gesehen = new List<string>();

        for (var runde = 0; runde < 3; runde++)
        {
            var ordner = MandantenImportAufbau.Ordner(await _aufbau.Buch.HoleAsync(Bestand, 2));
            gesehen.AddRange(ordner);
            await _aufbau.Uebernimm([], ohneBezug: [.. ordner]);
        }

        gesehen.Should().OnlyHaveUniqueItems();
        gesehen.Should().BeEquivalentTo(Bestand, "drei Pakete decken den Bestand genau ab");
    }

    // Der Bestand kommt aus einem Verzeichnisscan im Frontend; in welcher
    // Reihenfolge, sagt niemand zu. Das Paket muss trotzdem jedes Mal dasselbe
    // sein — sonst hinge die Zusage von oben an der Laune des Dateisystems.
    [Fact]
    public async Task Die_Reihenfolge_ist_alphabetisch_und_unabhaengig_vom_Eingang()
    {
        string[] gemischt =
        [
            "VUnfallursache Esch", "VUnfallursache Adler", "VUnfallursache Cramer",
            "VUnfallursache Berger", "VUnfallursache Dorn",
        ];

        var erstes = await _aufbau.Buch.HoleAsync(gemischt, 3);
        var zweites = await _aufbau.Buch.HoleAsync([.. gemischt.Reverse()], 3);

        MandantenImportAufbau.Ordner(erstes).Should().Equal(
            "VUnfallursache Adler", "VUnfallursache Berger", "VUnfallursache Cramer");
        MandantenImportAufbau.Ordner(zweites).Should()
            .Equal(MandantenImportAufbau.Ordner(erstes));
    }

    [Fact]
    public async Task Zugeordnete_und_vermerkte_Ordner_kommen_nicht_ins_Paket()
    {
        _aufbau.Vorhanden("Anna", "Adler", ["VUnfallursache Adler"]);
        await _aufbau.OrdnerStatus.SetzeAsync(
            ["VUnfallursache Berger"], OrdnerStatusArten.OhneMandantenbezug);

        var paket = await _aufbau.Buch.HoleAsync(Bestand, 10);

        MandantenImportAufbau.Ordner(paket).Should().Equal(
            "VUnfallursache Cramer", "VUnfallursache Dorn", "VUnfallursache Esch");
    }

    [Fact]
    public async Task Ein_Import_markiert_das_beruehrte_Paket_als_eingelesen()
    {
        await _aufbau.Buch.HoleAsync(Bestand, 3);

        await _aufbau.Uebernimm(
            [MandantenImportAufbau.Zeile("Anna", "Adler", ["VUnfallursache Adler"])],
            ohneBezug: ["VUnfallursache Berger"]);

        var paket = (await _aufbau.Buch.GetAllAsync()).Single();
        paket.EingelesenAm.Should().NotBeNull();
        paket.ErledigtAnzahl.Should().Be(2, "zugeordnet zählt wie vermerkt");
    }

    // Der zweite Lauf derselben Datei ist der Normalfall, weil der Erzeuger
    // nachbessert. Er darf am Buch nichts verändern — sonst wanderte
    // „eingelesen am" mit jedem Versuch nach vorn und die Historie verlöre
    // genau die Auskunft, für die es sie gibt.
    [Fact]
    public async Task Ein_zweiter_Lauf_derselben_Datei_aendert_das_Paket_nicht()
    {
        await _aufbau.Buch.HoleAsync(Bestand, 3);
        var zeilen = new[]
        {
            MandantenImportAufbau.Zeile("Anna", "Adler", ["VUnfallursache Adler"]),
        };

        await _aufbau.Uebernimm(zeilen, ohneBezug: ["VUnfallursache Berger"]);
        var nachDemErsten = (await _aufbau.Buch.GetAllAsync()).Single();
        var eingelesenAm = nachDemErsten.EingelesenAm;
        var erledigt = nachDemErsten.ErledigtAnzahl;

        await _aufbau.Uebernimm(zeilen, ohneBezug: ["VUnfallursache Berger"]);

        var nachDemZweiten = (await _aufbau.Buch.GetAllAsync()).Single();
        nachDemZweiten.EingelesenAm.Should().Be(eingelesenAm);
        nachDemZweiten.ErledigtAnzahl.Should().Be(erledigt);
    }

    // Dieselbe Trennung wie bei den Vermerken: die Vorschau zeigt, was
    // passieren würde, und hinterlässt nichts.
    [Fact]
    public async Task Die_Vorschau_markiert_kein_Paket()
    {
        await _aufbau.Buch.HoleAsync(Bestand, 3);

        await _aufbau.Vorschau(
            [MandantenImportAufbau.Zeile("Anna", "Adler", ["VUnfallursache Adler"])],
            ohneBezug: ["VUnfallursache Berger"]);

        var paket = (await _aufbau.Buch.GetAllAsync()).Single();
        paket.EingelesenAm.Should().BeNull();
        paket.ErledigtAnzahl.Should().Be(0);
    }

    [Fact]
    public async Task Die_Paketgroesse_wird_nach_oben_begrenzt()
    {
        var grosserBestand = Enumerable.Range(1, 1200)
            .Select(nummer => $"Akte {nummer:0000}")
            .ToArray();

        var paket = await _aufbau.Buch.HoleAsync(grosserBestand, 5000);

        MandantenImportAufbau.Ordner(paket).Should().HaveCount(ArbeitspaketBuch.GroesstesPaket);
    }

    [Fact]
    public async Task Mehr_angefordert_als_offen_liefert_alle_offenen()
    {
        var paket = await _aufbau.Buch.HoleAsync(Bestand, 500);

        MandantenImportAufbau.Ordner(paket).Should().Equal(Bestand);
    }

    [Fact]
    public async Task Eine_Anzahl_unter_eins_liefert_trotzdem_einen_Ordner()
    {
        var paket = await _aufbau.Buch.HoleAsync(Bestand, 0);

        MandantenImportAufbau.Ordner(paket).Should().Equal("VUnfallursache Adler");
    }

    // Der Bestand kommt aus einem Scan und nicht aus einem Formular: eine
    // doppelte Zeile oder ein leerer Name darf keinen Platz im Paket kosten.
    [Fact]
    public async Task Doppelte_und_leere_Ordnernamen_werden_uebergangen()
    {
        var paket = await _aufbau.Buch.HoleAsync(
            ["VUnfallursache Adler", "vunfallursache adler", "   ", "VUnfallursache Berger"], 10);

        MandantenImportAufbau.Ordner(paket).Should()
            .Equal("VUnfallursache Adler", "VUnfallursache Berger");
    }

    // Ein Paket ohne Ordner waere kein Paket, sondern eine Zeile, die fuer
    // immer wie ein nie eingelesenes Paket aussieht.
    [Fact]
    public async Task Ist_alles_erledigt_wird_kein_Paket_gebucht()
    {
        _aufbau.Vorhanden("Anna", "Adler", ["VUnfallursache Adler"]);
        await _aufbau.OrdnerStatus.SetzeAsync(
            [.. Bestand.Skip(1)], OrdnerStatusArten.OhneMandantenbezug);

        var holen = async () => await _aufbau.Buch.HoleAsync(Bestand, 200);

        await holen.Should().ThrowAsync<KeineOffenenOrdnerException>();
        (await _aufbau.Buch.GetAllAsync()).Should().BeEmpty();
    }

    [Fact]
    public async Task Die_Nummern_bleiben_nach_einem_gescheiterten_Holen_lueckenlos()
    {
        var erstes = await _aufbau.Buch.HoleAsync(Bestand, 200);
        await _aufbau.Uebernimm([], ohneBezug: Bestand);

        var holen = async () => await _aufbau.Buch.HoleAsync(Bestand, 200);
        await holen.Should().ThrowAsync<KeineOffenenOrdnerException>();

        // Der naechste Scan findet einen neuen Ordner — er bekommt Paket 2,
        // nicht Paket 3: der gescheiterte Griff hat keine Nummer verbraucht.
        var zweites = await _aufbau.Buch.HoleAsync([.. Bestand, "VUnfallursache Falk"], 200);

        erstes.Nummer.Should().Be(1);
        zweites.Nummer.Should().Be(2);
        MandantenImportAufbau.Ordner(zweites).Should().Equal("VUnfallursache Falk");
    }

    [Fact]
    public async Task Die_Historie_zeigt_das_neueste_Paket_zuerst()
    {
        await _aufbau.Buch.HoleAsync(Bestand, 2);
        await _aufbau.Uebernimm([], ohneBezug: ["VUnfallursache Adler", "VUnfallursache Berger"]);
        await _aufbau.Buch.HoleAsync(Bestand, 2);

        var historie = await _aufbau.Buch.GetAllAsync();

        historie.Select(paket => paket.Nummer).Should().Equal(2, 1);
    }
}
