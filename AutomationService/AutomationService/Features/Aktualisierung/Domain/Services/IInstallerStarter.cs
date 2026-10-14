namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Startet den Installer. Eine Naht, damit weder ein Test noch der
/// E2E-Testmodus je ein echtes Setup über die installierte App laufen lässt
/// (Attrappe: <c>TestmodusInstallerStarter</c>) — und ein Dienst aus der
/// Entwicklungsumgebung auch nicht (<see cref="Sperrgrund"/>).
/// </summary>
public interface IInstallerStarter
{
    /// <summary>
    /// Warum hier kein Installer starten darf, als Satz für den Anwender — oder
    /// <c>null</c>, wenn er darf. Ist er gesetzt, lehnt
    /// <see cref="IAktualisierungsDienst.Installiere"/> ab, bevor eine Merkdatei
    /// entsteht.
    /// </summary>
    string? Sperrgrund { get; }

    /// <summary>
    /// Kehrt zurück, sobald der Prozess läuft; wirft, wenn er nicht startet.
    /// Den <see cref="IInstallerLauf"/> entsorgt der Aufrufer.
    /// </summary>
    IInstallerLauf Starte(InstallerAufruf aufruf);
}
