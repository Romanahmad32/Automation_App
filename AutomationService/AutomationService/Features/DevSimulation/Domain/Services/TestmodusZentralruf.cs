using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Zentralruf-Anfrage im E2E-Testmodus (#168): kein Browser, kein Formular,
/// nur eine Zeile im <see cref="TestmodusProtokoll"/>. Die Antwort kommt wie
/// bisher über <c>POST api/Simulation/zentralruf-antwort</c>.
///
/// Die Referenz baut derselbe Code wie im echten Dienst
/// (<see cref="ZentralrufAutomationService.BuildReferenz"/>) — sonst passte die
/// simulierte Antwort im Testlauf zu einem Vorgang, zu dem die echte nie
/// gepasst hätte. Auch das Vorwärmen tut nichts: Es startete Playwright samt
/// Browser, und zwar schon beim Hochfahren (<c>ZentralrufWarmupService</c>).
/// </summary>
public sealed class TestmodusZentralruf(TestmodusProtokoll protokoll) : IZentralrufAutomationService
{
    public Task<ZentralrufPrefillResult> PrefillAsync(ZentralrufPrefillRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        var referenz = ZentralrufAutomationService.BuildReferenz(request);
        protokoll.Schreibe(TestmodusProtokoll.ZentralrufAnfrage, referenz, datei: null);
        return Task.FromResult(new ZentralrufPrefillResult(referenz, [], []));
    }

    public Task WarmupAsync() => Task.CompletedTask;
}
