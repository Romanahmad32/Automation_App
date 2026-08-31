using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// „Wie viele Zeilen stehen im Register" muss auf beiden Wegen dieselbe Zahl
/// ergeben — obwohl sie sie verschieden ermitteln.
///
/// <c>SchreibeAsync</c> baut jede Zeile und zählt die Liste;
/// <c>StandAsync</c> lässt die Datenbank zählen, weil es beim Öffnen der
/// Registerseite läuft und keine einzige Zeile anzeigt. Damit gibt es den
/// Dateifilter zweimal: einmal als <c>IstAbgeschlossen</c> in
/// <c>RegisterZeilenBau.Aus</c>, einmal als Ausdruck in
/// <c>RegisterZeilenBau.Dateifilter</c>, den EF Core nach SQL übersetzt.
///
/// Zwei Fassungen derselben fachlichen Regel laufen auseinander, sobald jemand
/// nur eine anfasst — und zwar unauffällig: Die Seite zeigt dann „37 Zeilen"
/// und die Datei enthält 41. Dieser Test ist die Klammer.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RegisterSpiegelZeilenzahlTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    /// <summary>
    /// Ein Bestand, in dem der Filter etwas zu tun hat: drei abgeschlossene
    /// Vorgänge, zwei laufende.
    /// </summary>
    async Task BestandAnlegen()
    {
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        await _umgebung.VorgangAnlegen("02/26 C03", 2);
        await _umgebung.VorgangAnlegen("03/26 C03", 3);
        await _umgebung.VorgangAnlegen("04/26 C03", 4, status: "angefragt");
        await _umgebung.VorgangAnlegen("05/26 C03", 5, status: "beantwortet");
    }

    [Theory]
    [InlineData("alle", 5)]
    [InlineData(RegisterSpiegelVorgabe.FilterAbgeschlossen, 3)]
    public async Task BeideWegeZaehlenDieselbenZeilen(string filter, int erwartet)
    {
        await _umgebung.EinstellungenAnlegen(filter: filter);
        await BestandAnlegen();

        var geschrieben = await _umgebung.Dienst().SchreibeAsync();
        var stand = await _umgebung.Dienst().StandAsync();

        geschrieben.Zeilen.Should().Be(erwartet);
        stand.Zeilen.Should().Be(erwartet, "die Seite zeigt sonst eine andere Zahl als die Datei enthält");
    }

    /// <summary>
    /// Ohne eingestellten Ablageordner wird nichts geschrieben — die Zahl muss
    /// die Seite trotzdem erreichen, sonst stünde dort „0 Zeilen" neben dem
    /// Hinweis, dass noch kein Ordner gewählt ist.
    /// </summary>
    [Fact]
    public async Task Stand_ZaehltAuchOhneAblageordner()
    {
        await _umgebung.EinstellungenAnlegen(ordner: string.Empty);
        await BestandAnlegen();

        var stand = await _umgebung.Dienst().StandAsync();

        stand.Geschrieben.Should().BeFalse();
        stand.Zeilen.Should().Be(5);
    }

    public void Dispose() => _umgebung.Dispose();
}
