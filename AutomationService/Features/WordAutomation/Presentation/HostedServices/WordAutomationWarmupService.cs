using AutomationService.Features.WordAutomation.Domain.Services;

namespace AutomationService.Features.WordAutomation.Presentation.HostedServices;

/// <summary>
/// Wärmt die DocX-Pipeline beim Anwendungsstart auf, damit der erste echte
/// Dokument-Request des Anwalts nicht den vollen JIT-Aufwand (~500 ms) zahlt.
/// Läuft im Hintergrund, blockiert also den Host-Start nicht.
/// </summary>
public sealed class WordAutomationWarmupService(
    IServiceScopeFactory scopeFactory,
    ILogger<WordAutomationWarmupService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        // Bewusst nicht awaited: Der Start soll nicht warten, bis der Warmup fertig ist.
        _ = Task.Run(() =>
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var service = scope.ServiceProvider.GetRequiredService<IWordAutomationService>();
                service.Warmup();
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
