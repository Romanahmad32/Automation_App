using AutomationService.Features.FormTemplates.Domain.Persistence;

namespace AutomationService.Features.FormTemplates.Domain.Services;

/// <summary>
/// Zugriff auf die benutzerdefinierten Formularvorlagen. Vergibt IDs und prüft
/// auf eindeutige Namen — Fachregeln, die mit dem Umstieg vom lokalen JSON-
/// Speicher ins Backend gewandert sind.
/// </summary>
public interface IFormTemplateRepository
{
    Task<IReadOnlyList<FormTemplateEntity>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <exception cref="FormTemplateNameConflictException">Name bereits vergeben.</exception>
    Task<FormTemplateEntity> CreateAsync(FormTemplateEntity neu, CancellationToken cancellationToken = default);

    /// <summary>Liefert null, wenn die ID unbekannt ist.</summary>
    /// <exception cref="FormTemplateNameConflictException">Name bereits von einer anderen vergeben.</exception>
    Task<FormTemplateEntity?> UpdateAsync(FormTemplateEntity template, CancellationToken cancellationToken = default);

    Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default);
}
