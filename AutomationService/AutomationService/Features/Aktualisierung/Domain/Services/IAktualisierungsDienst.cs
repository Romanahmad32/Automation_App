namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Aktualisierung aus der App heraus (#196): prüfen, herunterladen, prüfen,
/// Installer starten — und beim nächsten Start sagen, ob es geklappt hat.
///
/// Zustandsfolge: <c>unbekannt</c> → <c>aktuell</c> | <c>verfuegbar</c> →
/// <c>laedt</c> → <c>bereit</c>; jede gescheiterte Stufe endet in
/// <c>fehler</c> mit Meldung, von dort geht es mit Herunterladen oder Prüfen
/// weiter. Heruntergeladen wird erst auf Anforderung, nie von selbst.
/// </summary>
public interface IAktualisierungsDienst
{
    /// <summary>Der zwischengespeicherte Stand — billig, wird während des Downloads abgefragt.</summary>
    AktualisierungsStand Stand();

    /// <summary>
    /// Fragt die Quelle und aktualisiert den Stand. Läuft gerade ein Download
    /// oder liegt ein geprüfter bereit, bleibt der Zustand, wie er ist.
    /// </summary>
    Task<AktualisierungsStand> PruefeAsync(CancellationToken cancellationToken);

    /// <summary>Startet den Download im Hintergrund; idempotent bei <c>laedt</c> und <c>bereit</c>.</summary>
    AktualisierungsSchritt StarteDownload();

    /// <summary>Bricht einen laufenden Download ab und wartet, bis die Teildatei gelöscht ist.</summary>
    Task<AktualisierungsStand> BrecheAbAsync();

    /// <summary>
    /// Prüft die Setup-Datei erneut, schreibt die Merkdatei und startet den
    /// Installer. Abgelehnt, wenn nicht <c>bereit</c>, wenn hier kein Installer
    /// starten darf (<see cref="IInstallerStarter.Sperrgrund"/>, Zustand bleibt),
    /// wenn die Prüfung scheitert oder sich das Setup binnen
    /// <see cref="InstallerStart.Anlauffrist"/> wieder beendet (beides: <c>fehler</c>).
    /// Nur wenn der Installer danach noch läuft, fährt der Dienst kurz darauf
    /// selbst geordnet herunter (<see cref="IHerunterfahrenNachInstallerStart"/>).
    /// </summary>
    AktualisierungsSchritt Installiere();

    /// <summary>Löscht das Ergebnis der letzten Aktualisierung, nachdem das Frontend es gezeigt hat.</summary>
    void QuittiereErgebnis();

    /// <summary>Beim Start: Merkdatei auswerten, alte Setup-Dateien wegräumen.</summary>
    void Initialisiere();

    /// <summary>
    /// Zurück auf „nicht geprüft", als wäre der Dienst eben gestartet — Download
    /// abbrechen, Setup-Dateien löschen. Nur für den E2E-Testmodus, der mehrere
    /// Durchläufe gegen denselben Dienst fährt.
    /// </summary>
    Task SetzeZurueckAsync();
}
