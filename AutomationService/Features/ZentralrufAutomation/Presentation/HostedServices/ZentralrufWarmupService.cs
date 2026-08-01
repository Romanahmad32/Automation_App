using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.HostedServices;

/// <summary>
/// Wärmt die Playwright-Pipeline (Treiberprozess + Chromium) beim Anwendungsstart auf,
/// damit das erste "Anfrageformular ausfüllen" nicht den vollen Kaltstart zahlt.
/// Läuft im Hintergrund, blockiert also den Host-Start nicht.
/// </summary>
public sealed class ZentralrufWarmupService(
    IZentralrufAutomationService automationService,
    ILogger<ZentralrufWarmupService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        // Bewusst nicht awaited: Der Start soll nicht warten, bis der Warmup fertig ist.
        _ = Task.Run(async () =>
        {
            try
            {
                await automationService.WarmupAsync();
            }
            catch (Exception exception)
            {
                logger.LogWarning(exception, "Hintergrund-Warmup fehlgeschlagen (unkritisch).");
            }
        }, CancellationToken.None);

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
