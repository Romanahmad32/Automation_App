using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Die Vermerke zu Akten-Ordnern, die keinem Mandanten zugeordnet werden müssen
/// (§6.1). Setzen und Zurücknehmen laufen über denselben Aufruf, und beide
/// arbeiten auf einer <b>Liste</b> von Ordnern: einzeln wäre der Rest eines
/// Bestands von rund 4000 Ordnern nicht zu schaffen.
/// </summary>
public interface IOrdnerStatusRegister
{
    /// <summary>Alle gesetzten Vermerke.</summary>
    Task<IReadOnlyList<OrdnerStatusEntity>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Setzt <paramref name="status"/> für alle <paramref name="ordnernamen"/>;
    /// <c>null</c> nimmt den Vermerk zurück (der Ordner ist dann wieder offen).
    /// Gibt den vollständigen Stand danach zurück, damit der Aufrufer ihn in
    /// einem Zug übernehmen kann.
    /// </summary>
    /// <exception cref="ArgumentException">Unbekannter Status.</exception>
    Task<IReadOnlyList<OrdnerStatusEntity>> SetzeAsync(
        IReadOnlyList<string> ordnernamen,
        string? status,
        CancellationToken cancellationToken = default);
}
