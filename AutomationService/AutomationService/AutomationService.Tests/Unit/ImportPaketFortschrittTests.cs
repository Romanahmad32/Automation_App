using AutomationService.Features.Mandanten.Domain.Persistence;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Naht zwischen Import und Paket-Buchführung: Ein Schreiblauf
/// schließt jedes Paket, dessen Ordner er vollständig abdeckt — ohne dass
/// irgendwo eine Paketnummer mitgereist wäre. Genau das ist der Grund, warum
/// der Anwalt beim Import nichts auszuwählen hat, und deshalb wird es hier
/// über die echten Tabellen belegt und nicht über eine Attrappe.
/// </summary>
public sealed class ImportPaketFortschrittTests : IDisposable
{
    readonly MandantenImportAufbau _aufbau = new();

    ImportPaketEntity Paket() => _aufbau.Db.ImportPakete.AsNoTracking().Single();

    [Fact]
    public async Task Schreiblauf_SchliesstDasVollstaendigAbgedecktePaket()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier", "Akte Schmidt"]);

        await _aufbau.Uebernimm(
        [
            MandantenImportAufbau.Zeile("Anna", "Meier", ["Akte Meier"]),
            MandantenImportAufbau.Zeile("Karl", "Schmidt", ["Akte Schmidt"]),
        ]);

        var paket = Paket();
        paket.EingelesenAm.Should().NotBeNull();
        paket.Zeilen.Should().Be(2, "die Zeilenzahl der Datei, die es geschlossen hat");
    }

    [Fact]
    public async Task Schreiblauf_SchliesstAuchUeberVermerkteOrdner()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier", "Sammelordner"]);

        await _aufbau.Uebernimm(
            [MandantenImportAufbau.Zeile("Anna", "Meier", ["Akte Meier"])],
            ohneBezug: ["Sammelordner"]);

        Paket().EingelesenAm.Should().NotBeNull(
            "ein Vermerk nimmt den Ordner genauso aus dem Stapel wie eine Zuordnung");
    }

    [Fact]
    public async Task Schreiblauf_LaesstDasTeilweiseAbgedecktePaketOffen()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier", "Akte Schmidt"]);

        await _aufbau.Uebernimm([MandantenImportAufbau.Zeile("Anna", "Meier", ["Akte Meier"])]);

        var paket = Paket();
        paket.EingelesenAm.Should().BeNull("halb abgearbeitet ist nicht eingelesen");
        paket.Zeilen.Should().BeNull();

        var stand = await _aufbau.PaketBuch.GetAllAsync();
        stand.Should().ContainSingle().Which.Erledigt.Should().Be(1,
            "der Zähler zeigt dem Anwalt, wie weit das offene Paket ist");
    }

    [Fact]
    public async Task Prueflauf_VerbuchtNichts()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);

        await _aufbau.Vorschau([MandantenImportAufbau.Zeile("Anna", "Meier", ["Akte Meier"])]);

        Paket().EingelesenAm.Should().BeNull(
            "ohne Freigabe wird nichts geschrieben — auch keine Buchführung");
    }

    [Fact]
    public async Task Schreiblauf_SchliesstMehrerePaketeAufEinmal()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);
        await _aufbau.PaketBuch.NotiereAsync(["Akte Schmidt"]);

        await _aufbau.Uebernimm(
        [
            MandantenImportAufbau.Zeile("Anna", "Meier", ["Akte Meier"]),
            MandantenImportAufbau.Zeile("Karl", "Schmidt", ["Akte Schmidt"]),
        ]);

        var pakete = await _aufbau.Db.ImportPakete.AsNoTracking().ToListAsync();
        pakete.Should().OnlyContain(p => p.EingelesenAm != null);
        pakete.Should().OnlyContain(p => p.Zeilen == 2);
    }

    [Fact]
    public async Task Schreiblauf_LaesstEinBereitsGeschlossenesPaketInRuhe()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);
        await _aufbau.Uebernimm([MandantenImportAufbau.Zeile("Anna", "Meier", ["Akte Meier"])]);
        var geschlossenAm = Paket().EingelesenAm;

        await _aufbau.Uebernimm(
        [
            MandantenImportAufbau.Zeile("Karl", "Schmidt", ["Akte Schmidt"]),
            MandantenImportAufbau.Zeile("Eva", "Klein", ["Akte Klein"]),
        ]);

        var paket = Paket();
        paket.EingelesenAm.Should().Be(geschlossenAm, "ein geschlossenes Paket bleibt geschlossen");
        paket.Zeilen.Should().Be(1, "die Zeilenzahl gehört zu der Datei, die es geschlossen hat");
    }

    public void Dispose() => _aufbau.Dispose();
}
