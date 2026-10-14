namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Fährt den Dienst geordnet herunter, sobald der Installer läuft (#196) —
/// das Setup ersetzt ihn gleich und wartet, bis er fort ist.
///
/// Eine Naht: Tests prüfen den Anstoß, ohne ihren Wirt zu beenden, und der
/// E2E-Testmodus setzt <c>TestmodusHerunterfahren</c> ein, das nichts tut —
/// dort startet die Attrappe keinen Installer, und die Suite braucht den
/// Dienst für die nächsten Durchläufe.
/// </summary>
public interface IHerunterfahrenNachInstallerStart
{
    /// <summary>Kehrt sofort zurück; heruntergefahren wird erst nach einer kurzen Verzögerung.</summary>
    void StoesseAn();
}
