using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Services;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.WordAutomation.Presentation.HostedServices;

/// <summary>
/// Uebernimmt die mitgelieferten Vorlagen beim Start in den Vorlagenordner des
/// Anwenders — aber nur, solange kein eigener Ordner eingestellt ist (#33).
/// Wer seinen Ordner gewaehlt hat, bekommt nie wieder Muster nachgelegt: die
/// Einstellung liegt in der Datenbank und ueberlebt damit auch eine
/// Neuinstallation. Sonst legte die App ihm bei jedem Start Muster_*.docx in
/// die eigene Ablage — auf dem zweiten Rechner auch die, die er auf dem ersten
/// geloescht hat.
///
/// Blockierend im StartAsync, nicht im Hintergrund wie die Warmup-Dienste: die
/// Vorlagenliste darf beim ersten Oeffnen der Anwendung nicht leer sein. Das
/// Kopieren von zwei Dateien kostet Millisekunden.
///
/// Quelle ist <c>WordAutomation:TemplatesDirectory</c>, relativ zum
/// ContentRoot — im ausgelieferten Produkt also <c>backend\Templates</c>.
/// Hosted Services sind Singletons, das VorlagenVerzeichnis ist Scoped —
/// daher der eigene Scope (Muster: DatabaseMigrationService).
/// </summary>
public sealed class VorlagenSeedService(
    IServiceScopeFactory scopeFactory,
    IOptions<WordAutomationOptions> options,
    IHostEnvironment umgebung,
    ILogger<VorlagenSeedService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AutomationDbContext>();
            if (VorlagenOrdnerVorgabe.Eingestellt(db).Length > 0)
            {
                return Task.CompletedTask;
            }

            var vorlagen = scope.ServiceProvider.GetRequiredService<VorlagenVerzeichnis>();
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
