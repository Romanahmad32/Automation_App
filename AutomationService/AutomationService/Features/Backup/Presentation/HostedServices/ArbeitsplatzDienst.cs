using AutomationService.Features.Backup.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.HostedServices;

/// <summary>
/// Meldet den Arbeitsplatz an und ab (§7.2, #39): beim Start ein Eintrag „hier
/// wird gearbeitet", beim Beenden die Sicherung in den synchronisierten Ordner.
///
/// <para>
/// <b>Warum das Beenden hier hängt und nicht im Fenster.</b> Die App ist ein
/// Produkt aus zwei Prozessen; schliesst der Anwalt das Fenster, faehrt der
/// <c>ParentProcessWatchdog</c> diesen Dienst geordnet herunter — genau hier,
/// im StopAsync. Der Anwalt wartet damit am Feierabend auf nichts. Der Preis
/// ist, dass ihm in dem Moment niemand etwas sagen kann; deshalb merkt sich der
/// Lauf sein Ergebnis lokal, und der naechste Start zeigt einen Fehlschlag.
/// </para>
///
/// <para>
/// Die Anmeldung laeuft blockierend im StartAsync und damit vor der
/// Bereitschaftsmeldung. Das ist Absicht: Danach fragt das Frontend nach einem
/// Uebergabe-Angebot, und beide Seiten sollen dieselbe Akte sehen.
/// </para>
/// </summary>
public sealed class ArbeitsplatzDienst(
    IAutomatischeSicherung sicherung,
    ILogger<ArbeitsplatzDienst> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        sicherung.MerkeArbeitsbeginn();
        return Task.CompletedTask;
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        var ergebnis = await sicherung.SchreibeAsync(cancellationToken);
        if (ergebnis is null)
        {
            logger.LogInformation(
                "Keine automatische Sicherung: es ist kein Ablageordner eingestellt.");
        }
    }
}
