using AutomationService.Features.Aktualisierung.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Fährt nichts herunter und zählt nur mit (#196) — sonst beendete der erste
/// Installer-Start eines Integrationstests den Wirt, den die übrigen Tests
/// der Klasse noch brauchen.
/// </summary>
internal sealed class HerunterfahrenAttrappe : IHerunterfahrenNachInstallerStart
{
    private int _anstoesse;

    public int Anstoesse => Volatile.Read(ref _anstoesse);

    public void StoesseAn() => Interlocked.Increment(ref _anstoesse);
}
