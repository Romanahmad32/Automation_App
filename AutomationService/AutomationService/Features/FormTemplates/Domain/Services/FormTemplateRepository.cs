using AutomationService.Core.Persistence;
using AutomationService.Features.FormTemplates.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.FormTemplates.Domain.Services;

/// <summary>
/// EF-Core-Repository der Formularvorlagen. ID-Vergabe (max+1) und
/// Namens-Eindeutigkeit laufen serverseitig.
/// </summary>
public sealed class FormTemplateRepository(AutomationDbContext db) : IFormTemplateRepository
{
    public async Task<IReadOnlyList<FormTemplateEntity>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await db.FormTemplates.ToListAsync(cancellationToken);
    }

    public async Task<FormTemplateEntity> CreateAsync(FormTemplateEntity neu, CancellationToken cancellationToken = default)
    {
        await EnsureNameUniqueAsync(neu.TemplateName, eigeneId: null, cancellationToken);

        var maxId = await db.FormTemplates.AnyAsync(cancellationToken)
            ? await db.FormTemplates.MaxAsync(t => t.Id, cancellationToken)
            : 0;
        neu.Id = maxId + 1;

        db.FormTemplates.Add(neu);
        await db.SaveChangesAsync(cancellationToken);
        return neu;
    }

    public async Task<FormTemplateEntity?> UpdateAsync(FormTemplateEntity template, CancellationToken cancellationToken = default)
    {
        var existing = await db.FormTemplates.FirstOrDefaultAsync(t => t.Id == template.Id, cancellationToken);
        if (existing is null) return null;

        await EnsureNameUniqueAsync(template.TemplateName, eigeneId: template.Id, cancellationToken);

        existing.TemplateName = template.TemplateName;
        existing.FieldsJson = template.FieldsJson;
        existing.WordFilePathOhneAuflistung = template.WordFilePathOhneAuflistung;
        existing.WordFilePathMitAuflistung = template.WordFilePathMitAuflistung;

        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var existing = await db.FormTemplates.FirstOrDefaultAsync(t => t.Id == id, cancellationToken);
        if (existing is null) return false;

        db.FormTemplates.Remove(existing);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    async Task EnsureNameUniqueAsync(string templateName, int? eigeneId, CancellationToken ct)
    {
        // Bewusst getrennt: `t.Id != eigeneId` mit eigeneId == null würde EF zu
        // `Id <> NULL` übersetzen (SQL-Unknown) und nie matchen — beim Anlegen
        // bliebe die Dublette unerkannt.
        var konflikt = eigeneId is null
            ? await db.FormTemplates.AnyAsync(t => t.TemplateName == templateName, ct)
            : await db.FormTemplates.AnyAsync(
                t => t.TemplateName == templateName && t.Id != eigeneId.Value, ct);
        if (konflikt)
        {
            throw new FormTemplateNameConflictException(
                $"Vorlage mit Name {templateName} existiert bereits");
        }
    }
}
