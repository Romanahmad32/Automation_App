using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Services;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Regelfall des Mandantenimports: prüfen, übernehmen, noch einmal laufen
/// lassen. Der Anlass ist die Größenordnung — rund 4000 Ordner einzeln von Hand
/// zuzuordnen ist nicht leistbar. Was hier hineingeht, hat kein Mensch Zeile für
/// Zeile geschrieben; deshalb muss die Vorschau zeigen, was passiert, und ein
/// zweiter Lauf derselben Datei darf nichts anrichten.
/// </summary>
public sealed class MandantenImportTests : IDisposable
{
    readonly MandantenImportAufbau _aufbau = new();

    public void Dispose() => _aufbau.Dispose();

    [Fact]
    public async Task Vorschau_zeigt_das_Ergebnis_und_schreibt_nichts()
    {
        var befund = await _aufbau.Vorschau([
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ["VUnfallursache Schmidt"]),
        ]);

        befund.Angewendet.Should().BeFalse();
        befund.Neu.Should().Be(1);
        befund.OrdnerZugeordnet.Should().Be(1);
        befund.Eintraege.Single().Art.Should().Be(ImportArten.Neu);

        _aufbau.Db.Mandanten.Should().BeEmpty("eine Vorschau darf nichts anlegen");
    }

    [Fact]
    public async Task Uebernahme_legt_den_Mandanten_mit_seinem_Ordner_an()
    {
        await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile(
                "Mark", "Schmidt", ["VUnfallursache Schmidt"],
                anrede: "herr", ort: "Bad Homburg", kennzeichen: ["HG-E 1427"]),
        ]);

        var mandant = await _aufbau.Db.Mandanten.AsNoTracking().SingleAsync();
        mandant.Vorname.Should().Be("Mark");
        mandant.Anrede.Should().Be("herr");
        mandant.Ort.Should().Be("Bad Homburg");
        MandantListen.Lies(mandant.AktenOrdnernamenJson).Should().Equal("VUnfallursache Schmidt");
        MandantListen.Lies(mandant.KennzeichenJson).Should().Equal("HG-E 1427");
    }

    // Die Datei entsteht maschinell und wird eher zwei- als einmal eingelesen —
    // etwa nachdem der Erzeuger nachgebessert hat.
    [Fact]
    public async Task Ein_zweiter_Lauf_derselben_Datei_aendert_nichts()
    {
        var datei = new[]
        {
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ["VUnfallursache Schmidt"]),
        };

        await _aufbau.Uebernimm(datei);
        var zweiter = await _aufbau.Uebernimm(datei);

        zweiter.Neu.Should().Be(0);
        zweiter.Ergaenzt.Should().Be(0);
        zweiter.Unveraendert.Should().Be(1);
        zweiter.OrdnerZugeordnet.Should().Be(0);
        _aufbau.Db.Mandanten.Should().HaveCount(1);
    }

    // Schluessel vergibt die Datenbank. Eine Vorschau, die schon welche nennt,
    // laedt dazu ein, mit Nummern weiterzuarbeiten, die es nicht gibt.
    [Fact]
    public async Task Die_Vorschau_nennt_keine_Mandanten_Ids()
    {
        var zeile = MandantenImportAufbau.Zeile("Mark", "Schmidt");

        var vorschau = await _aufbau.Vorschau([zeile]);
        vorschau.Eintraege.Single().MandantId.Should().BeNull();

        var uebernommen = await _aufbau.Uebernimm([zeile]);
        uebernommen.Eintraege.Single().MandantId.Should().NotBeNull();
    }

    // Steht derselbe Mandant zweimal in der Datei, widerspricht sie sich
    // selbst — und nicht dem Register, das ihn noch gar nicht kennt.
    [Fact]
    public async Task Ein_Widerspruch_innerhalb_der_Datei_nennt_nicht_das_Register()
    {
        var befund = await _aufbau.Vorschau([
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ort: "Bad Homburg"),
            MandantenImportAufbau.Zeile("Mark", "Schmidt", ort: "Frankfurt"),
        ]);

        befund.Eintraege[1].Hinweise.Should().ContainSingle()
            .Which.Should().Contain("frühere Zeile").And.NotContain("Register");
    }

    [Fact]
    public async Task Ein_vorhandener_Mandant_bekommt_seine_zweite_Akte_dazu()
    {
        _aufbau.Vorhanden("Mark", "Schmidt", ["VUnfallursache Schmidt"]);

        var befund = await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile(
                "Mark", "Schmidt", ["VUnfallursache Schmidt", "Bußgeldsache Schmidt"]),
        ]);

        befund.Ergaenzt.Should().Be(1);
        befund.Eintraege.Single().AktenOrdnernamen.Should().Equal("Bußgeldsache Schmidt");
        _aufbau.OrdnerVon("Schmidt").Should()
            .Equal("VUnfallursache Schmidt", "Bußgeldsache Schmidt");
    }

    // Ergänzen, nie überschreiben: die Datei liest aus alten Schreiben und darf
    // gepflegte Stammdaten nicht durch eine Lesart daraus ersetzen.
    [Fact]
    public async Task Leere_Felder_werden_gefuellt_belegte_bleiben_stehen()
    {
        _aufbau.Vorhanden("Mark", "Schmidt", ort: "Bad Homburg");

        var befund = await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile(
                "Mark", "Schmidt", ort: "Frankfurt", strasse: "Hauptstraße 12"),
        ]);

        var mandant = await _aufbau.Db.Mandanten.AsNoTracking().SingleAsync();
        mandant.StrasseHausnummer.Should().Be("Hauptstraße 12", "das Feld war leer");
        mandant.Ort.Should().Be("Bad Homburg", "das Feld war gepflegt");

        befund.Eintraege.Single().Hinweise.Should()
            .ContainSingle(h => h.Contains("Ort weicht ab") && h.Contains("Frankfurt"));
    }

    [Fact]
    public async Task Eine_Zeile_ohne_Namen_wird_abgelehnt()
    {
        var befund = await _aufbau.Uebernimm([
            MandantenImportAufbau.Zeile("", "", ["Irgendein Ordner"]),
        ]);

        befund.Abgelehnt.Should().Be(1);
        befund.OrdnerZugeordnet.Should().Be(0);
        befund.Eintraege.Single().Hinweise.Should().ContainSingle();
        _aufbau.Db.Mandanten.Should().BeEmpty();
    }
}
