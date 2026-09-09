using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Löscht eine historische Registerzeile für sich (§6.3) — der Weg für Zeilen
/// ohne Vorgang. Eine Spiegelzeile eines Vorgangs geht nur über
/// <c>VorgangLoeschung</c> (siehe <see cref="VorgangLoeschungTests"/>).
/// </summary>
public sealed class RegisterHistorieLoeschenTests : IDisposable
{
    readonly RegisterImportAufbau _aufbau = new();

    [Fact]
    public async Task Loesche_EntferntDieZeile()
    {
        await _aufbau.Uebernimm(2019, RegisterImportAufbau.Zeile(1, jahr: "19"));
        var gespeichert = _aufbau.Gespeichert(2019, 1);

        var geloescht = await _aufbau.Historie.LoescheAsync(gespeichert.Id);

        geloescht.Should().BeTrue();
        (await _aufbau.Historie.GetAsync(gespeichert.Id)).Should().BeNull();
    }

    [Fact]
    public async Task Loesche_MeldetEineUnbekannteZeileAlsFalse()
    {
        var geloescht = await _aufbau.Historie.LoescheAsync(4711);

        geloescht.Should().BeFalse();
    }

    public void Dispose() => _aufbau.Dispose();
}
