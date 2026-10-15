using AutomationService.Features.Aktualisierung.Domain.Services;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.Aktualisierung.Presentation.HostedServices;

/// <summary>
/// Was beim Start des Dienstes für die Aktualisierung zu tun ist (#196).
///
/// <see cref="StartingAsync"/> läuft vor dem <c>StartAsync</c> aller
/// Hintergrunddienste, also noch vor Migration und Sicherung: Die
/// <see cref="DienstLaeuftMarke"/> steht damit, bevor der Dienst irgendeine
/// Datei anfasst. <see cref="StartAsync"/> wertet die Merkdatei aus und räumt
/// alte Setup-Dateien weg — schnell und ohne Netz; geprüft wird erst, wenn das
/// Frontend fragt.
/// </summary>
public sealed class AktualisierungStartDienst(
    IAktualisierungsDienst dienst,
    IHostEnvironment umgebung,
    IOptions<AktualisierungOptions> optionen,
    ILogger<AktualisierungStartDienst> logger) : IHostedLifecycleService
{
    public Task StartingAsync(CancellationToken cancellationToken)
    {
        if (DienstLaeuftMarke.NameFuer(umgebung) is { } name)
        {
            DienstLaeuftMarke.Halte(name, logger);
        }

        return Task.CompletedTask;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        // Umgelenkt wird nur für die Abnahme mit Testversionen (Aktualisierung__Quelle,
        // #199). Eine Zeile auf der Konsole des Dienstes — zu lesen, wenn er in einem
        // Terminal läuft (dotnet run, AutomationService.exe von Hand). Die installierte
        // App schreibt kein Protokoll in eine Datei; dort landet die Zeile nur unter den
        // letzten Ausgaben, die BackendLauncher bei einem Startfehler zeigt.
        var quelle = optionen.Value.Quelle;
        if (!string.Equals(quelle, AktualisierungOptions.VorgabeQuelle, StringComparison.Ordinal))
        {
            logger.LogInformation(
                "Aktualisierungen kommen aus einer umgelenkten Quelle: {Quelle} (Vorgabe: {Vorgabe}).",
                quelle,
                AktualisierungOptions.VorgabeQuelle);
        }

        try
        {
            dienst.Initialisiere();
        }
        catch (Exception ausnahme)
        {
            // Ein Merker und ein Aufräumen dürfen den Start nicht aufhalten.
            logger.LogWarning(ausnahme, "Die Merkdatei der letzten Aktualisierung ließ sich nicht auswerten.");
        }

        return Task.CompletedTask;
    }

    public Task StartedAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StoppingAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StoppedAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
