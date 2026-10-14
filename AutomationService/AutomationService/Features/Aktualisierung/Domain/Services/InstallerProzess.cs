using System.Diagnostics;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Das echte Setup als Prozess (#196). Gestartet wird über die Shell
/// (<see cref="InstallerStarter"/>), und dann darf <see cref="Process.Start(ProcessStartInfo)"/>
/// <c>null</c> liefern, obwohl der Prozess läuft — dann gilt er als laufend:
/// Ohne Handle lässt sich nicht sehen, ob er endet, und im Zweifel geht der
/// Weg weiter wie vor der Anlauffrist.
///
/// Inno beendet seinen äußeren Prozess (<c>setup.exe</c>) erst mit dem inneren
/// (<c>setup.tmp</c>), der die eigentliche Arbeit tut — das Handle steht also
/// für das ganze Setup.
/// </summary>
public sealed class InstallerProzess(Process? prozess) : IInstallerLauf
{
    public int? WarteAufEnde(TimeSpan frist)
    {
        if (prozess is null)
        {
            return null;
        }

        try
        {
            return prozess.WaitForExit(frist) ? prozess.ExitCode : null;
        }
        catch (InvalidOperationException)
        {
            // Kein Prozess mehr zugeordnet — nichts zu beobachten.
            return null;
        }
    }

    public void Dispose() => prozess?.Dispose();
}
