using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Zugriff auf das Mandantenregister (§5.1). Vergibt IDs und prüft auf
/// Namens-Dubletten — Fachregeln, die mit dem Umstieg vom lokalen JSON-Register
/// ins Backend gewandert sind.
/// </summary>
public interface IMandantenRepository
{
    /// <summary>Alle Mandanten, neueste zuerst.</summary>
    Task<IReadOnlyList<MandantEntity>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>Legt einen Mandanten an (ID + ErstelltAm werden vergeben).</summary>
    /// <exception cref="MandantNameConflictException">Name bereits vergeben.</exception>
    Task<MandantEntity> CreateAsync(MandantEntity neu, CancellationToken cancellationToken = default);

    /// <summary>Aktualisiert einen Mandanten. Liefert null, wenn die ID unbekannt ist.</summary>
    /// <exception cref="MandantNameConflictException">Name bereits von einem anderen vergeben.</exception>
    Task<MandantEntity?> UpdateAsync(MandantEntity mandant, CancellationToken cancellationToken = default);

    /// <summary>Löscht den Mandanten. false, wenn die ID unbekannt war.</summary>
    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);
}
