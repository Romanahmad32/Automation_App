using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Zusicherung des <c>RegisterSpiegelController</c> im Wortlaut: „Beide
/// Wege antworten immer mit 200 und einem Ergebnis."
///
/// Der Satz steht am Controller und in <c>docs/openapi.json</c>, gehalten wird
/// er aber hier — der Controller reicht nur durch. Wirft der Dienst, entsteht
/// eine 500, und die Oberfläche zeigt statt eines erklärenden Satzes einen
/// Verbindungsfehler: Der Anwalt liest dann „Dienst nicht erreichbar", obwohl
/// der Dienst läuft und die Lage in zehn Sekunden behebbar wäre.
///
/// Der Auslöser ist bewusst grob gewählt — eine Datenschicht, die nicht mehr
/// antwortet. Er steht für alles, woran beim Schreiben nicht gedacht wurde:
/// einen Ablageordner, den jemand über <c>PUT api/Settings/kanzlei</c> auf
/// einen unmöglichen Pfad gestellt hat, eine Datenbank, die währenddessen
/// wegzieht, alles, was Xceed beim Bauen der .docx werfen kann. Geprüft wird
/// nicht der einzelne Auslöser, sondern dass keiner von ihnen als Ausnahme
/// nach oben durchschlägt.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RegisterSpiegelVertragTests : IDisposable
{
    readonly RegisterSpiegelUmgebung _umgebung = new();

    /// <summary>
    /// Bringt die Datenschicht zum Ausfall, nachdem alles eingerichtet ist.
    /// Jeder Zugriff wirft danach — und zwar aus <c>LadeAsync</c>, also aus dem
    /// allerersten Schritt beider Wege.
    /// </summary>
    async Task DatenschichtFaelltAus()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        _umgebung.Db.Dispose();
    }

    [Fact]
    public async Task Schreibe_MeldetEinenUnerwartetenFehlschlagAlsErgebnis()
    {
        await DatenschichtFaelltAus();

        var ergebnis = await _umgebung.Dienst().SchreibeAsync();

        ergebnis.Geschrieben.Should().BeFalse();
        ergebnis.Fehler.Should().Contain("unerwartet");
    }

    [Fact]
    public async Task Stand_MeldetEinenUnerwartetenFehlschlagAlsErgebnis()
    {
        await DatenschichtFaelltAus();

        var ergebnis = await _umgebung.Dienst().StandAsync();

        ergebnis.Geschrieben.Should().BeFalse();
        ergebnis.Fehler.Should().Contain("unerwartet");
    }

    /// <summary>
    /// Die Ausnahme von der Ausnahme: Ein abgebrochener Aufruf ist kein
    /// Ergebnis, das jemand lesen will. Bliebe er im Netz hängen, meldete der
    /// Dienst dem abgereisten Aufrufer ein „gescheitert", und ASP.NET könnte
    /// den Abbruch nicht mehr von einem echten Fehlschlag unterscheiden.
    /// </summary>
    [Fact]
    public async Task Schreibe_LaesstEinenAbbruchDurch()
    {
        await _umgebung.EinstellungenAnlegen();
        await _umgebung.VorgangAnlegen("01/26 C03", 1);
        using var abbruch = new CancellationTokenSource();
        await abbruch.CancelAsync();

        var lauf = async () => await _umgebung.Dienst().SchreibeAsync(
            erzwingen: true, cancellationToken: abbruch.Token);

        await lauf.Should().ThrowAsync<OperationCanceledException>();
    }

    public void Dispose() => _umgebung.Dispose();
}
