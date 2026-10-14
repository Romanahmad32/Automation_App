using AutomationService.Features.Aktualisierung.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Reicht an eine austauschbare Quelle weiter (#196) — damit ein Testwirt, der
/// für die ganze Testklasse einmal startet, je Test eine andere Quelle
/// bekommen kann (etwa eine langsame für den Abbruch). Selbst ist sie keine
/// Testmodus-Attrappe: <c>POST api/Simulation/aktualisierung</c> lehnt sie ab.
/// </summary>
internal sealed class UmschaltbareQuelle(IAktualisierungsQuelle innen) : IAktualisierungsQuelle
{
    private volatile IAktualisierungsQuelle _innen = innen;

    public IAktualisierungsQuelle Innen
    {
        get => _innen;
        set => _innen = value;
    }

    public Task<ReleaseBeschreibung> HoleNeuesteAsync(CancellationToken cancellationToken) =>
        Innen.HoleNeuesteAsync(cancellationToken);

    public Task<Stream> OeffneAsync(Uri adresse, CancellationToken cancellationToken) =>
        Innen.OeffneAsync(adresse, cancellationToken);
}
