using System.Diagnostics;

namespace AutomationService.Core.Lifetime;

/// <summary>
/// Faehrt den Dienst herunter, sobald der Prozess endet, der ihn gestartet hat.
///
/// Das Produkt ist <em>eine</em> Anwendung: der Anwalt startet das Frontend, das
/// diesen Dienst als Kindprozess mitbringt (Aufrufparameter
/// <c>--parent-pid &lt;PID&gt;</c>). Ohne diesen Waechter ueberlebt der Dienst
/// jedes Schliessen des Fensters — und der naechste Start scheitert am belegten
/// Port oder arbeitet gegen eine zweite Instanz auf derselben Datenbank.
///
/// Bewusst ein StopApplication() statt eines harten Abschusses durch das
/// Frontend: nur beim regulaeren Shutdown laufen die StopAsync/Dispose der
/// uebrigen Dienste — insbesondere gibt die PDF-Konvertierung ihre
/// Word-COM-Instanz frei. Ein TerminateProcess wuerde WINWORD.EXE verwaisen
/// lassen.
///
/// Ohne <c>--parent-pid</c> wird der Waechter nicht registriert; beim
/// Entwickeln (<c>dotnet run</c>) laeuft der Dienst also unveraendert
/// eigenstaendig weiter.
/// </summary>
public sealed class ParentProcessWatchdog(
    int parentProcessId,
    IHostApplicationLifetime lifetime,
    ILogger<ParentProcessWatchdog> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        Process elternprozess;
        try
        {
            elternprozess = Process.GetProcessById(parentProcessId);
        }
        catch (ArgumentException)
        {
            // Der Elternprozess war schon weg, bevor wir ihn greifen konnten.
            logger.LogWarning(
                "Elternprozess {ParentProcessId} laeuft nicht mehr; der Dienst beendet sich sofort.",
                parentProcessId);
            lifetime.StopApplication();
            return;
        }

        using (elternprozess)
        {
            try
            {
                await elternprozess.WaitForExitAsync(stoppingToken);
            }
            catch (OperationCanceledException)
            {
                // Regulaerer Shutdown des Dienstes — nichts zu tun.
                return;
            }
        }

        logger.LogInformation(
            "Elternprozess {ParentProcessId} wurde beendet; der Dienst faehrt herunter.",
            parentProcessId);
        lifetime.StopApplication();
    }
}
