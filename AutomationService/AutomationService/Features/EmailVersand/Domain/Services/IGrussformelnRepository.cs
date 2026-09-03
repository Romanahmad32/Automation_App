using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der Bestand der persönlichen Grußformeln (§4.7, §7.1) — gepflegt in den
/// Einstellungen, gewählt beim Verfassen.
/// </summary>
public interface IGrussformelnRepository
{
    /// <summary>Alle Grüße in ihrer Reihenfolge — so stehen sie zur Auswahl.</summary>
    Task<IReadOnlyList<GrussformelEntity>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <exception cref="GrussformelTextConflictException">Gruß bereits vorhanden.</exception>
    Task<GrussformelEntity> CreateAsync(GrussformelEntity neu, CancellationToken cancellationToken = default);

    /// <summary>Liefert null, wenn die Id unbekannt ist.</summary>
    /// <exception cref="GrussformelTextConflictException">Gruß bereits von einem anderen belegt.</exception>
    Task<GrussformelEntity?> UpdateAsync(GrussformelEntity grussformel, CancellationToken cancellationToken = default);

    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);
}
