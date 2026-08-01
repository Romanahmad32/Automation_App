using AutomationService.Features.PdfConversion.Domain.Services;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.PdfConversion.Presentation.HostedServices;

/// <summary>
/// Startet die Word-Instanz für die PDF-Vorschau bereits beim Anwendungsstart,
/// damit die erste Vorschau des Anwalts nicht die Word-Startzeit (~1-3 s) zahlt.
/// Läuft im Hintergrund, blockiert also den Host-Start nicht.
/// </summary>
public sealed class PdfConversionWarmupService(
    IWordInteropPdfConverter wordConverter,
    IOptions<PdfConversionOptions> options,
    ILogger<PdfConversionWarmupService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        if (!options.Value.WarmupOnStartup ||
            options.Value.Engine != PdfConversionOptions.EngineWordInterop)
        {
            return Task.CompletedTask;
        }

        // Bewusst nicht awaited: Der Start soll nicht warten, bis Word bereit ist.
        _ = Task.Run(async () =>
        {
            try
            {
                await wordConverter.WarmupAsync();
            }
            catch (Exception exception)
            {
                logger.LogWarning(exception, "Word-Warmup fehlgeschlagen (unkritisch, Fallback greift bei Bedarf).");
            }
        }, CancellationToken.None);

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
