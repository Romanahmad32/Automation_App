using System.Diagnostics;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Startet die Setup-Datei losgelöst vom Dienst (#196).
///
/// <c>UseShellExecute = true</c> ist hier die eigentliche Entscheidung: Ohne
/// Shell erbte das Setup die Handles des Dienstes — darunter die
/// Ausgabe-Pipes, die das Frontend hält —, und es soll den Dienst überleben,
/// den es gleich ersetzt. Gewartet wird nur die kurze Anlauffrist
/// (<see cref="InstallerStart.Anlauffrist"/>); das Setup wartet seinerseits in
/// <c>InitializeSetup</c>, bis der Dienst beendet ist.
///
/// <b>Nur in der installierten App (Production).</b> Ein Dienst aus der
/// Entwicklungsumgebung (<c>dotnet run</c>, <c>flutter run</c>) lädt
/// dasselbe echte Setup von GitHub — gestartet überschriebe es die App, die
/// auf dem Entwicklerrechner installiert ist. Dort lehnt <see cref="Sperrgrund"/>
/// ab; der E2E-Testmodus ersetzt diesen Starter ohnehin durch seine Attrappe.
/// </summary>
public sealed class InstallerStarter(IHostEnvironment umgebung, ILogger<InstallerStarter> logger) : IInstallerStarter
{
    public string? Sperrgrund => umgebung.IsProduction() ? null : AktualisierungsMeldungen.NurInstalliert;

    public IInstallerLauf Starte(InstallerAufruf aufruf)
    {
        ArgumentNullException.ThrowIfNull(aufruf);

        // Zweite Sicherung: Der Dienst fragt Sperrgrund vorher ab, aber wer
        // diese Klasse anders verwendet, startet trotzdem nichts.
        if (Sperrgrund is { } grund)
        {
            throw new InvalidOperationException(grund);
        }

        var start = new ProcessStartInfo(aufruf.SetupPfad, aufruf.Argumente)
        {
            UseShellExecute = true,
            WorkingDirectory = aufruf.Arbeitsordner,
        };

        // Gescheitert ist der Start nur, wenn er wirft; ein null hier heißt
        // nicht, dass nichts läuft (siehe InstallerProzess).
        var prozess = Process.Start(start);
        logger.LogInformation(
            "Installer für {Version} gestartet: {Setup} {Argumente}",
            aufruf.ZielVersion,
            aufruf.SetupPfad,
            aufruf.Argumente);
        return new InstallerProzess(prozess);
    }
}
