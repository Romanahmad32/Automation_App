using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.HostedServices;

/// <summary>
/// Räumt beim Anwendungsstart die zwischengelagerten Anhänge ab, die seit zwei
/// Wochen niemand mehr angefasst hat (§4.3, §4.7) — dieselbe Rolle, die
/// <c>WordAutomationWarmupService</c> für die Arbeitsordner hat.
///
/// Das Netz unter dem Aufräumen von Hand: Der Anwalt verwirft geholte
/// Vorschläge einzeln, aber niemand verwirft die Anhänge einer Antwort, die er
/// nie beantwortet hat. Läuft im Hintergrund, blockiert den Start also nicht.
/// </summary>
public sealed class AnhangAufraeumService(
    AnhangAblage ablage,
    ILogger<AnhangAufraeumService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        // Bewusst nicht awaited: Der Start soll nicht auf das Aufräumen warten.
        _ = Task.Run(
            () =>
            {
                try
                {
                    ablage.AltesLoeschen();
                }
                catch (Exception exception)
                {
                    logger.LogWarning(exception, "Aufräumen der Anhänge fehlgeschlagen (unkritisch).");
                }
            },
            CancellationToken.None);

        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
