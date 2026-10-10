using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Services;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.Vollmacht.Presentation.HostedServices;

/// <summary>
/// Legt die neutralen Vollmacht-Muster beim Start in den Unterordner
/// <c>Vollmacht/</c> — nach derselben Regel wie der <c>VorlagenSeedService</c>
/// der Anspruchsschreiben (#33): nur in den App-eigenen Vorlagenordner, nie in
/// einen, den der Anwalt selbst gewählt hat.
///
/// Für die Vollmacht wiegt das schwerer als für die Anspruchsschreiben: Ein
/// Muster trägt keinen Kanzleikopf. Läge es unter dem festen Namen im Ordner
/// der Kanzlei, druckte die App eine Vollmacht ohne Bevollmächtigten — und
/// meldete Erfolg. Fehlt die Datei dort, sagen Dialog und Einstellungen es.
/// </summary>
public sealed class VollmachtVorlagenSeedService(
    IServiceScopeFactory scopeFactory,
    IOptions<WordAutomationOptions> options,
    IHostEnvironment umgebung,
    ILogger<VollmachtVorlagenSeedService> logger) : IHostedService
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

            var quelle = Path.Combine(
                umgebung.ContentRootPath,
                options.Value.TemplatesDirectory,
                VollmachtArten.Unterordner);
            scope.ServiceProvider.GetRequiredService<VollmachtVorlagenOrdner>().Ergaenze(quelle);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(exception, "Vollmacht-Muster konnten nicht übernommen werden.");
        }

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
