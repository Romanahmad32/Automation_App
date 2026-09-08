using AutomationService.Features.Mandanten.Domain.Persistence;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Buchführung über die Arbeitspakete gegen eine echte
/// In-Memory-SQLite. Zwei Dinge stehen hier auf dem Spiel: die Paketnummer,
/// die der Anwalt im Dateinamen wiederfindet, und der erledigt-Zähler, der
/// aus zwei Tabellen zugleich gerechnet wird — beides ließe sich gegen eine
/// Attrappe nicht ehrlich prüfen.
/// </summary>
public sealed class ImportPaketBuchTests : IDisposable
{
    readonly MandantenImportAufbau _aufbau = new();

    [Fact]
    public async Task NotiereAsync_VergibtFortlaufendeNummernAbEins()
    {
        var erstes = await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);
        var zweites = await _aufbau.PaketBuch.NotiereAsync(["Akte Schmidt"]);

        erstes.Paket.Nummer.Should().Be(1);
        zweites.Paket.Nummer.Should().Be(2);
        erstes.Paket.GeholtAm.Should().NotBe(default);
        erstes.Paket.EingelesenAm.Should().BeNull("ein soeben geholtes Paket ist offen");
        erstes.Paket.Zeilen.Should().BeNull();
    }

    [Fact]
    public async Task GetAllAsync_LiefertDasJuengstePaketZuerst()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);
        await _aufbau.PaketBuch.NotiereAsync(["Akte Schmidt"]);

        var stand = await _aufbau.PaketBuch.GetAllAsync();

        stand.Select(p => p.Paket.Nummer).Should().ContainInOrder(2, 1);
    }

    [Fact]
    public async Task NotiereAsync_OhneOrdnerWirdAbgelehnt()
    {
        var versuch = () => _aufbau.PaketBuch.NotiereAsync([]);

        await versuch.Should().ThrowAsync<ArgumentException>(
            "ein Paket ohne Ordner wäre eine Nummer ohne Arbeit dahinter");
    }

    [Fact]
    public async Task NotiereAsync_OhneBrauchbareNamenWirdAbgelehnt()
    {
        var versuch = () => _aufbau.PaketBuch.NotiereAsync(["   ", ""]);

        await versuch.Should().ThrowAsync<ArgumentException>();
    }

    [Fact]
    public async Task NotiereAsync_EntdoppeltOhneRuecksichtAufSchreibweise()
    {
        var paket = await _aufbau.PaketBuch.NotiereAsync(["Akte A", "akte a"]);

        paket.Paket.AnzahlOrdner.Should().Be(1,
            "derselbe Windows-Ordner in zwei Schreibweisen ist ein Ordner");
        MandantListen.Lies(paket.Paket.OrdnernamenJson).Should().ContainSingle();
    }

    [Fact]
    public async Task Erledigt_ZaehltZugeordneteUndVermerkteOrdner()
    {
        _aufbau.Vorhanden("Anna", "Meier", ["Akte Meier"]);
        await _aufbau.OrdnerStatus.SetzeAsync(
            ["Sammelordner"], OrdnerStatusArten.OhneMandantenbezug);

        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier", "Sammelordner", "Akte Offen"]);
        var stand = await _aufbau.PaketBuch.GetAllAsync();

        stand.Should().ContainSingle().Which.Erledigt.Should().Be(2,
            "zugeordnet und vermerkt sind beide aus dem Zuordnungsstapel heraus");
        stand[0].Paket.AnzahlOrdner.Should().Be(3);
        stand[0].Paket.EingelesenAm.Should().BeNull("ein Ordner ist noch offen");
    }

    [Fact]
    public async Task Erledigt_VergleichtOhneRuecksichtAufSchreibweise()
    {
        _aufbau.Vorhanden("Anna", "Meier", ["akte meier"]);
        await _aufbau.OrdnerStatus.SetzeAsync(
            ["sammelordner"], OrdnerStatusArten.OhneMandantenbezug);

        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier", "SAMMELORDNER"]);
        var stand = await _aufbau.PaketBuch.GetAllAsync();

        stand.Should().ContainSingle().Which.Erledigt.Should().Be(2);
    }

    [Fact]
    public async Task Erledigt_SinktWiederWennEinOrdnerFreiWird()
    {
        await _aufbau.OrdnerStatus.SetzeAsync(
            ["Sammelordner"], OrdnerStatusArten.OhneMandantenbezug);
        await _aufbau.PaketBuch.NotiereAsync(["Sammelordner", "Akte Offen"]);

        (await _aufbau.PaketBuch.GetAllAsync())[0].Erledigt.Should().Be(1);

        await _aufbau.OrdnerStatus.SetzeAsync(["Sammelordner"], null);

        (await _aufbau.PaketBuch.GetAllAsync())[0].Erledigt.Should().Be(0,
            "der Zähler wird gerechnet und nicht gespeichert — er kann nicht veralten");
    }

    [Fact]
    public async Task LoescheAsync_NimmtEinOffenesPaketZurueck()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);

        var geloescht = await _aufbau.PaketBuch.LoescheAsync(1);

        geloescht.Should().BeTrue();
        (await _aufbau.PaketBuch.GetAllAsync()).Should().BeEmpty();
    }

    [Fact]
    public async Task LoescheAsync_UnbekanntePaketnummerLiefertFalse()
    {
        var geloescht = await _aufbau.PaketBuch.LoescheAsync(1);

        geloescht.Should().BeFalse();
    }

    [Fact]
    public async Task LoescheAsync_RuehrtKeinenOrdnerAn()
    {
        _aufbau.Vorhanden("Anna", "Meier", ["Akte Meier"]);
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);

        await _aufbau.PaketBuch.LoescheAsync(1);

        (await _aufbau.Register.GetAllAsync()).Should().ContainSingle(
            "das Paket war nur eine Buchführungszeile, keine Reservierung");
    }

    [Fact]
    public async Task LoescheAsync_LehntEinBereitsEingelesenesPaketAb()
    {
        await _aufbau.PaketBuch.NotiereAsync(["Akte Meier"]);
        await _aufbau.Uebernimm([MandantenImportAufbau.Zeile("Anna", "Meier", ["Akte Meier"])]);

        var versuch = () => _aufbau.PaketBuch.LoescheAsync(1);

        await versuch.Should().ThrowAsync<InvalidOperationException>(
            "sonst sähe es nach einem Rückgängig der eingelesenen Mandanten aus, ohne einen zurückzunehmen");
        (await _aufbau.PaketBuch.GetAllAsync()).Should().ContainSingle();
    }

    public void Dispose() => _aufbau.Dispose();
}
