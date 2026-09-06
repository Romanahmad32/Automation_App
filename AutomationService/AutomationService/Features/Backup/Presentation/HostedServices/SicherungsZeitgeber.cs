using AutomationService.Features.Backup.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.HostedServices;

/// <summary>
/// Sichert während der Arbeit in festem Takt (§7.2, #112) — der dritte Auslöser
/// neben dem Beenden (<see cref="ArbeitsplatzDienst"/>) und dem
/// Vorgangsabschluss.
///
/// <para>
/// <b>Warum überhaupt.</b> Zwischen Öffnen am Morgen und Schließen am Abend lag
/// bisher alles ungesichert, sofern kein Vorgang abgeschlossen wurde. Ein
/// Absturz, ein Stromausfall, ein „Rechner neu starten" von Windows nahm den
/// ganzen Tag mit.
/// </para>
///
/// <para>
/// <b>Nur bei Änderung.</b> Ohne das <see cref="AenderungsMerkmal"/> entstünden
/// an einem Tag ohne Eingaben ein Dutzend gleicher Archive — und verdrängten in
/// der <see cref="Aufbewahrungsregel"/> genau die Historie, für die sie da ist.
/// </para>
///
/// <para>
/// <b>Wirft nie</b> (§1.3: kein stilles Scheitern, aber auch kein Absturz aus
/// einer Nebensache heraus). Ein Fehlschlag steht in der
/// <c>LetzteSicherungAkte</c> und geht beim nächsten Start auf den Bildschirm;
/// der Takt läuft weiter.
/// </para>
/// </summary>
/// <param name="sicherung">Dieselbe Sicherung wie beim Beenden — mitsamt Schleuse.</param>
/// <param name="datenbankPfad">
/// Liefert den Pfad der Datenbankdatei je Takt neu. Als Funktion, damit ein Test
/// nicht das echte Benutzerprofil braucht — dasselbe Muster wie beim Ablageordner.
/// </param>
/// <param name="logger">Hält Fehlschläge im Protokoll fest.</param>
/// <param name="intervall">Nur für Tests; ab Werk <see cref="Intervall"/>.</param>
public sealed class SicherungsZeitgeber(
    IAutomatischeSicherung sicherung,
    Func<string> datenbankPfad,
    ILogger<SicherungsZeitgeber> logger,
    TimeSpan? intervall = null) : BackgroundService
{
    /// <summary>
    /// Der Takt. Eine halbe Stunde ist der Ausgleich zwischen „höchstens eine
    /// halbe Stunde Arbeit verloren" und „das Archiv trägt die Vorlagen jedes
    /// Mal ein weiteres Mal mit".
    /// </summary>
    public static readonly TimeSpan Intervall = TimeSpan.FromMinutes(30);

    /// <summary>
    /// Der Stand, der zuletzt gesichert wurde. Leer heißt „noch nichts bekannt" —
    /// dann sichert der nächste Takt in jedem Fall.
    /// </summary>
    string _stand = string.Empty;

    /// <summary>
    /// Ein Takt: Hat sich seit der letzten Sicherung etwas geändert, wird
    /// gesichert. Öffentlich, damit die Tests den Lauf anstoßen können, statt auf
    /// eine halbe Stunde zu warten.
    /// </summary>
    /// <returns><c>true</c>, wenn ein Archiv geschrieben wurde.</returns>
    public async Task<bool> TickAsync()
    {
        var stand = Stand();
        if (string.Equals(stand, _stand, StringComparison.Ordinal))
        {
            return false;
        }

        LetzteSicherung? ergebnis;
        try
        {
            // Ohne Abbruchmarke: Ein Lauf, der begonnen hat, soll zu Ende gehen.
            // Das Beenden wartet ohnehin an der Schleuse in AutomatischeSicherung.
            ergebnis = await sicherung.SchreibeAsync(CancellationToken.None);
        }
        catch (Exception ex)
        {
            // Die Sicherung wirft laut Vertrag nicht. Käme hier trotzdem etwas
            // durch, riss es den Hintergrunddienst und mit ihm den ganzen Takt.
            logger.LogError(ex, "Zeitgesteuerte Sicherung fehlgeschlagen.");
            return false;
        }

        if (ergebnis is null || !ergebnis.Gelungen)
        {
            // Abgeschaltet oder misslungen: Der Stand bleibt ungemerkt, damit es
            // der nächste Takt erneut versucht.
            return false;
        }

        // Nach dem Lauf neu lesen: Das Sichern öffnet die Datenbank selbst
        // (VACUUM INTO) und rührt dabei die WAL-Seitendateien an. Der Stand von
        // vorher wäre schon im nächsten Takt wieder „geändert".
        _stand = Stand();
        return true;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Startwert vor dem ersten Takt — und nicht erst beim ersten Takt: Was
        // zwischen Start und erster halber Stunde geschrieben wurde, soll die
        // erste Sicherung mitnehmen.
        _stand = Stand();

        using var takt = new PeriodicTimer(intervall ?? Intervall);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (!await takt.WaitForNextTickAsync(stoppingToken))
                {
                    break;
                }

                if (stoppingToken.IsCancellationRequested)
                {
                    // Beim Beenden sichert der ArbeitsplatzDienst. Ein hier neu
                    // begonnener Lauf hielte das Herunterfahren nur auf.
                    break;
                }

                await TickAsync();
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                // Ein Takt, der am ersten unerreichbaren Ordner stirbt, ist
                // schlimmer als keiner: Niemand merkt, dass nichts mehr kommt.
                logger.LogError(ex, "Zeitgesteuerte Sicherung übersprungen; der Takt läuft weiter.");
            }
        }
    }

    /// <summary>Der aktuelle Fingerabdruck der Datenbank. Wirft nie.</summary>
    string Stand()
    {
        try
        {
            return AenderungsMerkmal.Fingerabdruck(datenbankPfad());
        }
        catch (Exception ex)
        {
            // Der Pfad kommt aus einer Funktion, die in den Dienstcontainer
            // greifen darf — beim Herunterfahren kann der darunter weg sein.
            logger.LogWarning(ex, "Änderungsstand der Datenbank nicht lesbar.");
            return "?";
        }
    }
}
