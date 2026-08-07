using AutomationService.Features.WordAutomation.Domain.Services;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.WordAutomation.Presentation.HostedServices;

/// <summary>
/// Uebernimmt die mitgelieferten Vorlagen beim Start in den Vorlagenordner des
/// Anwenders.
///
/// Blockierend im StartAsync, nicht im Hintergrund wie die Warmup-Dienste: die
/// Vorlagenliste darf beim ersten Oeffnen der Anwendung nicht leer sein. Das
/// Kopieren von zwei Dateien kostet Millisekunden.
///
/// Quelle ist <c>WordAutomation:TemplatesDirectory</c>, relativ zum
/// ContentRoot — im ausgelieferten Produkt also <c>backend\Templates</c>.
/// </summary>
public sealed class VorlagenSeedService(
    VorlagenVerzeichnis vorlagen,
    IOptions<WordAutomationOptions> options,
    IHostEnvironment umgebung,
    ILogger<VorlagenSeedService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        try
        {
            var quelle = Path.Combine(umgebung.ContentRootPath, options.Value.TemplatesDirectory);
            vorlagen.Ergaenze(quelle);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            // Kein Grund, die Anwendung nicht zu starten: der Anwalt kann seine
            // Vorlagen auch von Hand verlinken. Nur wissen muss man es.
            logger.LogWarning(
                exception, "Mitgelieferte Vorlagen konnten nicht uebernommen werden.");
        }

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
