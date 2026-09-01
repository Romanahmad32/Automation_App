using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// EF-Core-Repository der Mail-Textvorlagen. Id-Vergabe (max+1) und
/// Namens-Eindeutigkeit laufen serverseitig — dieselbe Aufteilung wie bei den
/// Formularvorlagen (<c>FormTemplateRepository</c>).
/// </summary>
public sealed class MailVorlagenRepository(AutomationDbContext db) : IMailVorlagenRepository
{
    public async Task<IReadOnlyList<MailVorlageEntity>> GetAllAsync(
        CancellationToken cancellationToken = default)
        => await db.MailVorlagen
            .AsNoTracking()
            .OrderBy(v => v.Name)
            .ToListAsync(cancellationToken);

    public async Task<MailVorlageEntity> CreateAsync(
        MailVorlageEntity neu,
        CancellationToken cancellationToken = default)
    {
        await EnsureNameUniqueAsync(neu.Name, eigeneId: null, cancellationToken);

        var maxId = await db.MailVorlagen.AnyAsync(cancellationToken)
            ? await db.MailVorlagen.MaxAsync(v => v.Id, cancellationToken)
            : 0;
        neu.Id = maxId + 1;

        db.MailVorlagen.Add(neu);
        await db.SaveChangesAsync(cancellationToken);
        return neu;
    }

    public async Task<MailVorlageEntity?> UpdateAsync(
        MailVorlageEntity vorlage,
        CancellationToken cancellationToken = default)
    {
        var existing = await db.MailVorlagen
            .FirstOrDefaultAsync(v => v.Id == vorlage.Id, cancellationToken);
        if (existing is null) return null;

        await EnsureNameUniqueAsync(vorlage.Name, eigeneId: vorlage.Id, cancellationToken);

        existing.Name = vorlage.Name;
        existing.Betreff = vorlage.Betreff;
        existing.Text = vorlage.Text;

        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var existing = await db.MailVorlagen.FirstOrDefaultAsync(v => v.Id == id, cancellationToken);
        if (existing is null) return false;

        db.MailVorlagen.Remove(existing);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    async Task EnsureNameUniqueAsync(string name, int? eigeneId, CancellationToken ct)
    {
        // Bewusst getrennt: `v.Id != eigeneId` mit eigeneId == null würde EF zu
        // `Id <> NULL` übersetzen (SQL-Unknown) und nie treffen — beim Anlegen
        // bliebe die Dublette unerkannt.
        var konflikt = eigeneId is null
            ? await db.MailVorlagen.AnyAsync(v => v.Name == name, ct)
            : await db.MailVorlagen.AnyAsync(v => v.Name == name && v.Id != eigeneId.Value, ct);
        if (konflikt)
        {
            throw new MailVorlageNameConflictException(
                $"Eine Mail-Vorlage mit dem Namen {name} gibt es bereits");
        }
    }
}
