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
        Bereinige(neu);
        await EnsureTextUniqueAsync(neu.Text, eigeneId: null, cancellationToken);

        neu.Id = await BestandVergabe.NaechsteIdAsync(db.Grussformeln, cancellationToken);

        // Ans Ende, wenn nichts vorgegeben ist: Ein neuer Gruss soll die
        // gewohnte Reihenfolge der vorhandenen nicht durcheinanderbringen.
        if (neu.Sortierung == 0)
        {
            neu.Sortierung = await BestandVergabe.NaechsteSortierungAsync(
                db.Grussformeln, cancellationToken);
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

        Bereinige(grussformel);
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

    /// <summary>
    /// Schneidet Leerraum ab und besteht auf einem Wortlaut. Vor der
    /// Eindeutigkeitsprüfung, damit „ Gruß " kein zweiter Eintrag neben „Gruß"
    /// wird — siehe <see cref="GrussformelUngueltigException"/>.
    /// </summary>
    static void Bereinige(GrussformelEntity grussformel)
    {
        grussformel.Text = grussformel.Text?.Trim() ?? string.Empty;
        if (grussformel.Text.Length > 0) return;

        throw new GrussformelUngueltigException("Der Gruss braucht einen Text");
    }

    async Task EnsureTextUniqueAsync(string text, int? eigeneId, CancellationToken ct)
    {
        var konflikt = await BestandVergabe.GibtEsSchonAsync(
            db.Grussformeln.Where(g => g.Text == text), eigeneId, ct);
        if (konflikt)
        {
            throw new GrussformelTextConflictException($"Den Gruss \"{text}\" gibt es bereits");
        }
    }
}
