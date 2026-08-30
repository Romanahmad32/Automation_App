using AutomationService.Features.Settings.Domain.Persistence;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Liest und speichert die Standardpositionen der Schadensaufstellung (§4.4).
/// Gespeichert wird immer die komplette Liste; eine leere Liste setzt auf die
/// Vorgabe zurück (<see cref="StandardSchadenspositionenVorgabe"/>).
/// </summary>
public interface IStandardSchadenspositionenRepository
{
    Task<IReadOnlyList<StandardSchadenspositionEntity>> GetAsync(
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<StandardSchadenspositionEntity>> SaveAsync(
        IReadOnlyList<StandardSchadenspositionEntity> positionen,
        CancellationToken cancellationToken = default);
}
