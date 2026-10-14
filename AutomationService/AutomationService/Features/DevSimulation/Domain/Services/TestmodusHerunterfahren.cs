using AutomationService.Features.Aktualisierung.Domain.Services;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Herunterfahren nach dem Installer-Start im E2E-Testmodus (#196): tut nichts.
/// Die Attrappe <see cref="TestmodusInstallerStarter"/> startet kein Setup, das
/// den Dienst ersetzen wollte, und die Suite fährt danach weitere Durchläufe
/// gegen denselben Dienst. Die App bleibt im Testmodus ebenfalls offen
/// (<c>AktualisierungCubit.testmodus</c>).
/// </summary>
public sealed class TestmodusHerunterfahren(ILogger<TestmodusHerunterfahren> logger) : IHerunterfahrenNachInstallerStart
{
    public void StoesseAn() =>
        logger.LogInformation("Testmodus: Der Dienst bleibt nach dem (nur protokollierten) Installer-Start an.");
}
