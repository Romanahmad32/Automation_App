namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Beendet den Dienst nach dem Start des echten Installers über
/// <see cref="IHostApplicationLifetime.StopApplication"/> (#196) — derselbe
/// geordnete Weg wie beim <c>ParentProcessWatchdog</c>: Die Sicherung wird
/// geschrieben, die Word-Instanz freigegeben, und mit dem Prozess endet der
/// Mutex, auf den das Setup in <c>InitializeSetup</c> wartet.
///
/// Nötig, weil nicht jeder Dienst einen Wächter hat: Hat das Frontend beim
/// Start einen schon laufenden Dienst übernommen (<c>BackendLauncher</c>,
/// <c>bereitsGestartet</c>), bekam der kein <c>--parent-pid</c> und liefe nach
/// „Jetzt neu starten" weiter. Das Setup wartete dann 90 s vergeblich und
/// überließe den Rest dem Restart Manager. Hat er einen Wächter, schadet der
/// zweite Anstoß nicht: Wer zuerst kommt, fährt herunter, der andere findet
/// <see cref="IHostApplicationLifetime.ApplicationStopping"/> schon ausgelöst.
/// </summary>
public sealed class GeordnetesHerunterfahren(
    IHostApplicationLifetime lebensdauer,
    ILogger<GeordnetesHerunterfahren> logger,
    TimeProvider? zeit = null) : IHerunterfahrenNachInstallerStart
{
    /// <summary>
    /// Fünf Sekunden, nachdem der Installer die Anlauffrist überstanden hat
    /// (<see cref="InstallerStart.Anlauffrist"/>, 3 s) — rund acht nach seinem
    /// Start. Nach unten: Die Antwort 202 auf <c>POST installieren</c> muss
    /// sicher beim Frontend sein, und das Frontend zeigt danach 2 s lang „Die
    /// App wird jetzt geschlossen …" (2e), bevor es sich selbst beendet
    /// (<c>AktualisierungCubit.schliessPause</c>). Ginge der Dienst vorher, sähe
    /// der Anwalt statt 2e den Startfehler der App. Nach oben: Das Setup wartet
    /// ab seinem Start höchstens 90 s, und das Herunterfahren selbst darf 60 s
    /// dauern (Sicherung, <c>HostOptions.ShutdownTimeout</c>) — 3 + 5 + 60
    /// lässt genug Reserve.
    /// </summary>
    public static readonly TimeSpan Verzoegerung = TimeSpan.FromSeconds(5);

    private readonly TimeProvider _zeit = zeit ?? TimeProvider.System;

    public void StoesseAn() => _ = StoesseAnAsync();

    /// <summary>
    /// Der Anstoß als abwartbarer Task — <see cref="StoesseAn"/> lässt ihn laufen,
    /// ein Test wartet ihn ab, bevor er prüft.
    /// </summary>
    public async Task StoesseAnAsync()
    {
        try
        {
            await Task.Delay(Verzoegerung, _zeit, lebensdauer.ApplicationStopping);
        }
        catch (OperationCanceledException)
        {
            // Der Dienst fährt schon herunter — etwa über den Wächter, weil
            // die App zuerst zu war.
            return;
        }

        logger.LogInformation("Der Installer läuft; der Dienst fährt geordnet herunter, damit das Setup ihn ersetzen kann.");
        lebensdauer.StopApplication();
    }
}
