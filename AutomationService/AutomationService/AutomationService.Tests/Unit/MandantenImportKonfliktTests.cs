using AutomationService.Features.Mandanten.Domain.Persistence;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Was der Import mit Widersprüchen macht. Eine maschinell erzeugte Datei über
/// tausende Ordner enthält welche — dieselbe Person zweimal, ein Ordner an zwei
/// Stellen, ein Ordner, der schon jemandem gehört. Keiner davon darf still
/// gewinnen: entweder es passiert das Offensichtliche, oder es steht als
/// Hinweis in der Vorschau.
/// </summary>
public sealed class MandantenImportKonfliktTests : IDisposable
{
    readonly MandantenImportAufbau _aufbau = new();

    public void Dispose() => _aufbau.Dispose();

    [Fact]
    public async Task Ein_fremder_Ordner_wird_nicht_umgehaengt()
    {
        _aufbau.Vorhanden("Mark", "Schmidt", ["VUnfallursache Schmidt"]);

        var befund = await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile("Saeed", "Bein", ["VUnfallursache Schmidt"]),
        ]);

        befund.Eintraege.Single().AktenOrdnernamen.Should().BeEmpty();
        befund.Eintraege.Single().Hinweise.Should()
            .ContainSingle(h => h.Contains("gehört bereits") && h.Contains("Mark Schmidt"));
        _aufbau.OrdnerVon("Schmidt").Should().Equal("VUnfallursache Schmidt");
        _aufbau.OrdnerVon("Bein").Should().BeEmpty();
    }

    // Zwei Zeilen, ein Name: der Erzeuger hat denselben Mandanten aus zwei
    // Akten gelesen. Das Register wies eine Dublette ohnehin mit 409 ab — der
    // Import darf sie deshalb nicht durch die Hintertür anlegen.
    [Fact]
    public async Task Zwei_Zeilen_mit_demselben_Namen_ergeben_einen_Mandanten()
    {
        var befund = await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ["VUnfallursache Schmidt"]),
            MandantenImportAufbau.Zeile("mark", " Schmidt ", ["Bußgeldsache Schmidt"]),
        ]);

        befund.Neu.Should().Be(1);
        befund.Ergaenzt.Should().Be(1);
        _aufbau.Db.Mandanten.Should().HaveCount(1);
        _aufbau.OrdnerVon("Schmidt").Should()
            .Equal("VUnfallursache Schmidt", "Bußgeldsache Schmidt");
    }

    [Fact]
    public async Task Denselben_Ordner_bekommt_nur_die_erste_Zeile()
    {
        var befund = await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ["Unfallsache 2019"]),
            MandantenImportAufbau.Zeile("Saeed", "Bein", ["Unfallsache 2019"]),
        ]);

        befund.OrdnerZugeordnet.Should().Be(1);
        _aufbau.OrdnerVon("Schmidt").Should().Equal("Unfallsache 2019");
        _aufbau.OrdnerVon("Bein").Should().BeEmpty();
        befund.Eintraege[1].Hinweise.Should().ContainSingle(h => h.Contains("gehört bereits"));
    }

    [Fact]
    public async Task Ordner_ohne_Mandantenbezug_werden_vermerkt()
    {
        var befund = await _aufbau.Uebernimm([], ohneBezug: ["Buchhaltung 2019", "Vorlagen"]);

        befund.OhneMandantenbezug.Should().Be(2);
        var vermerke = await _aufbau.OrdnerStatus.GetAllAsync();
        vermerke.Select(v => v.Ordnername).Should().BeEquivalentTo("Buchhaltung 2019", "Vorlagen");
        vermerke.Should().OnlyContain(v => v.Status == OrdnerStatusArten.OhneMandantenbezug);
    }

    // Ein Ordner kann nicht gleichzeitig einem Mandanten gehören und keinem.
    // Die Zuordnung ist die stärkere Aussage — in beide Richtungen.
    [Fact]
    public async Task Eine_Zuordnung_sticht_den_Vermerk_in_derselben_Datei()
    {
        var befund = await _aufbau.Uebernimm(
            [MandantenImportAufbau.Zeile("Mark", "Schmidt", ["Unfallsache 2019"])],
            ohneBezug: ["Unfallsache 2019", "Vorlagen"]);

        befund.OhneMandantenbezug.Should().Be(1);
        var vermerke = await _aufbau.OrdnerStatus.GetAllAsync();
        vermerke.Select(v => v.Ordnername).Should().Equal("Vorlagen");
    }

    [Fact]
    public async Task Eine_Zuordnung_nimmt_einen_vorhandenen_Vermerk_zurueck()
    {
        await _aufbau.OrdnerStatus.SetzeAsync(
            ["Unfallsache 2019"], OrdnerStatusArten.OhneMandantenbezug);

        await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ["Unfallsache 2019"]),
        ]);

        var vermerke = await _aufbau.OrdnerStatus.GetAllAsync();
        vermerke.Should().BeEmpty("der Ordner gehört jetzt einem Mandanten");
    }

    [Fact]
    public async Task Ein_bereits_zugeordneter_Ordner_wird_nicht_als_bezuglos_vermerkt()
    {
        _aufbau.Vorhanden("Mark", "Schmidt", ["VUnfallursache Schmidt"]);

        var befund = await _aufbau.Uebernimm([], ohneBezug: ["VUnfallursache Schmidt"]);

        befund.OhneMandantenbezug.Should().Be(0);
        (await _aufbau.OrdnerStatus.GetAllAsync()).Should().BeEmpty();
    }

    // Dieselbe Invariante, nur mit der Schreibweise der Datei gegen die des
    // Dateisystems. Griffe der Ruecknahme-Aufruf hier daneben, waere der Ordner
    // einem Mandanten zugeordnet *und* als bezuglos vermerkt.
    [Fact]
    public async Task Eine_Zuordnung_nimmt_den_Vermerk_auch_bei_anderer_Schreibweise_zurueck()
    {
        await _aufbau.OrdnerStatus.SetzeAsync(
            ["VUnfallursache Schmidt"], OrdnerStatusArten.OhneMandantenbezug);

        await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ["vunfallursache schmidt"]),
        ]);

        (await _aufbau.OrdnerStatus.GetAllAsync()).Should().BeEmpty();
    }

    // Der zweite Lauf derselben Datei ist der Normalfall, weil der Erzeuger
    // nachbessert. Er darf keine Wirkung behaupten, die es nicht gibt.
    [Fact]
    public async Task Ein_schon_vermerkter_Ordner_zaehlt_im_zweiten_Lauf_nicht_mit()
    {
        await _aufbau.Uebernimm([], ohneBezug: ["Vorlagen", "Buchhaltung 2019"]);

        var zweiter = await _aufbau.Uebernimm([], ohneBezug: ["Vorlagen", "buchhaltung 2019"]);

        zweiter.OhneMandantenbezug.Should().Be(0);
        (await _aufbau.OrdnerStatus.GetAllAsync()).Should().HaveCount(2);
    }

    [Fact]
    public async Task Die_Vorschau_beruehrt_auch_die_Vermerke_nicht()
    {
        await _aufbau.Vorschau(
            [MandantenImportAufbau.Zeile("Mark", "Schmidt", ["Unfallsache 2019"])],
            ohneBezug: ["Vorlagen"]);

        (await _aufbau.OrdnerStatus.GetAllAsync()).Should().BeEmpty();
        (await _aufbau.Db.Mandanten.AsNoTracking().AnyAsync()).Should().BeFalse();
    }
}
