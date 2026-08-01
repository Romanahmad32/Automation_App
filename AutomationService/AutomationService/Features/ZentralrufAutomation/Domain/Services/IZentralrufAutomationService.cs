using AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

public interface IZentralrufAutomationService
{
    /// <summary>
    /// Öffnet ein sichtbares Browserfenster mit dem Zentralruf-Anfrageformular und füllt es voraus.
    /// Captcha und Absenden verbleiben beim Benutzer.
    /// </summary>
    Task<ZentralrufPrefillResult> PrefillAsync(ZentralrufPrefillDto prefillDto);

    /// <summary>
    /// Wärmt die Playwright-Pipeline (Treiberprozess + Chromium) vor, damit der erste
    /// echte Prefill nicht den vollen Kaltstart zahlt. Öffnet kein sichtbares Fenster.
    /// </summary>
    Task WarmupAsync();
}

public sealed record ZentralrufPrefillResult(
    string Referenz,
    IReadOnlyList<string> FilledFields,
    IReadOnlyList<string> SkippedFields);
