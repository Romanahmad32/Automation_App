namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Ein gestartetes Setup, soweit der Dienst es beobachten muss (#196) — für
/// genau eine Frage: Hat es sich gleich wieder beendet? Das tut ein Setup, das
/// gar nicht erst anfängt — etwa weil schon ein zweites läuft
/// (<c>SetupLaeuftMutex</c> in <c>setup.iss</c>, im stillen Lauf ohne Rückfrage) oder ein Virenscanner
/// es abbricht. Führe der Dienst dann trotzdem herunter, schlösse sich auch die
/// App, und der Anwalt stünde ohne App und ohne Update da.
/// </summary>
public interface IInstallerLauf : IDisposable
{
    /// <summary>
    /// Wartet höchstens <paramref name="frist"/>. Der Rückgabewert des Setups,
    /// wenn es sich in dieser Zeit beendet hat; sonst <c>null</c> — es läuft,
    /// oder der Dienst kann es nicht beobachten.
    /// </summary>
    int? WarteAufEnde(TimeSpan frist);
}
