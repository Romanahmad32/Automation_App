using AutomationService.Features.EmailVersand.Domain.Persistence;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der Bestand der Anredeanfänge (§4.7, §7.1) — gepflegt in den Einstellungen,
/// gewählt beim Verfassen.
/// </summary>
public interface IAnredeBausteineRepository
{
    /// <summary>Alle Anfänge in ihrer Reihenfolge — so stehen sie zur Auswahl.</summary>
    Task<IReadOnlyList<AnredeBausteinEntity>> GetAllAsync(
        CancellationToken cancellationToken = default);

    /// <exception cref="AnredeBausteinConflictException">Anfang bereits vorhanden.</exception>
    Task<AnredeBausteinEntity> CreateAsync(
        AnredeBausteinEntity neu,
        CancellationToken cancellationToken = default);

    /// <summary>Liefert null, wenn die Id unbekannt ist.</summary>
    /// <exception cref="AnredeBausteinConflictException">Anfang bereits von einem anderen belegt.</exception>
    Task<AnredeBausteinEntity?> UpdateAsync(
        AnredeBausteinEntity baustein,
        CancellationToken cancellationToken = default);

    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);
}
