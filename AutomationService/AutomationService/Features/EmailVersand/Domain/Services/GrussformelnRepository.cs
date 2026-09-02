using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// EF-Core-Repository der Grußformeln. Id-Vergabe (max+1) und Eindeutigkeit
/// des Textes laufen serverseitig — dieselbe Aufteilung wie bei den
/// Mail-Textvorlagen (<see cref="MailVorlagenRepository"/>).
/// </summary>
public sealed class GrussformelnRepository(AutomationDbContext db) : IGrussformelnRepository
{
    public async Task<IReadOnlyList<GrussformelEntity>> GetAllAsync(
        CancellationToken cancellationToken = default)
        => await db.Grussformeln
            .AsNoTracking()
            .OrderBy(g => g.Sortierung)
            .ThenBy(g => g.Text)
            .ToListAsync(cancellationToken);

    public async Task<GrussformelEntity> CreateAsync(
        GrussformelEntity neu,
        CancellationToken cancellationToken = default)
    {
        await EnsureTextUniqueAsync(neu.Text, eigeneId: null, cancellationToken);

        var vorhanden = await db.Grussformeln.AnyAsync(cancellationToken);
        neu.Id = vorhanden
            ? await db.Grussformeln.MaxAsync(g => g.Id, cancellationToken) + 1
            : 1;

        // Ans Ende, wenn nichts vorgegeben ist: Ein neuer Gruss soll die
        // gewohnte Reihenfolge der vorhandenen nicht durcheinanderbringen.
        if (neu.Sortierung == 0)
        {
            neu.Sortierung = vorhanden
                ? await db.Grussformeln.MaxAsync(g => g.Sortierung, cancellationToken) + 10
                : 10;
        }

        db.Grussformeln.Add(neu);
        await db.SaveChangesAsync(cancellationToken);
        return neu;
    }

    public async Task<GrussformelEntity?> UpdateAsync(
        GrussformelEntity grussformel,
        CancellationToken cancellationToken = default)
    {
        var existing = await db.Grussformeln
            .FirstOrDefaultAsync(g => g.Id == grussformel.Id, cancellationToken);
        if (existing is null) return null;

        await EnsureTextUniqueAsync(grussformel.Text, eigeneId: grussformel.Id, cancellationToken);

        existing.Text = grussformel.Text;
        if (grussformel.Sortierung != 0) existing.Sortierung = grussformel.Sortierung;

        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var existing = await db.Grussformeln.FirstOrDefaultAsync(g => g.Id == id, cancellationToken);
        if (existing is null) return false;

        db.Grussformeln.Remove(existing);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    async Task EnsureTextUniqueAsync(string text, int? eigeneId, CancellationToken ct)
    {
        // Bewusst getrennt: `g.Id != eigeneId` mit eigeneId == null würde EF zu
        // `Id <> NULL` übersetzen (SQL-Unknown) und nie treffen.
        var konflikt = eigeneId is null
            ? await db.Grussformeln.AnyAsync(g => g.Text == text, ct)
            : await db.Grussformeln.AnyAsync(g => g.Text == text && g.Id != eigeneId.Value, ct);
        if (konflikt)
        {
            throw new GrussformelTextConflictException($"Den Gruss \"{text}\" gibt es bereits");
        }
    }
}
