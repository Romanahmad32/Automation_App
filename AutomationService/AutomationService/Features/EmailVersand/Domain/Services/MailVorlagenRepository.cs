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
        Bereinige(neu);
        await EnsureNameUniqueAsync(neu.Name, eigeneId: null, cancellationToken);

        neu.Id = await BestandVergabe.NaechsteIdAsync(db.MailVorlagen, cancellationToken);

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

        Bereinige(vorlage);
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

    /// <summary>
    /// Schneidet Leerraum an Name und Betreff ab und besteht auf einem Namen.
    /// Vor der Eindeutigkeitsprüfung, damit „ Anschreiben " keine zweite
    /// Vorlage neben „Anschreiben" wird — siehe
    /// <see cref="MailVorlageUngueltigException"/>.
    /// </summary>
    /// <remarks>
    /// Der <b>Text bleibt unangetastet</b>: Dort ist Leerraum Aufbau, keine
    /// Unachtsamkeit. Eine führende Leerzeile kann gewollt sein, und das
    /// Zeilenende steht am Ausgangsbestand aus gutem Grund fest
    /// (<see cref="MailVorlagenVorgabe"/>).
    /// </remarks>
    static void Bereinige(MailVorlageEntity vorlage)
    {
        vorlage.Name = vorlage.Name?.Trim() ?? string.Empty;
        vorlage.Betreff = vorlage.Betreff?.Trim() ?? string.Empty;
        if (vorlage.Name.Length > 0) return;

        throw new MailVorlageUngueltigException("Die Mail-Vorlage braucht einen Namen");
    }

    async Task EnsureNameUniqueAsync(string name, int? eigeneId, CancellationToken ct)
    {
        var konflikt = await BestandVergabe.GibtEsSchonAsync(
            db.MailVorlagen.Where(v => v.Name == name), eigeneId, ct);
        if (konflikt)
        {
            throw new MailVorlageNameConflictException(
                $"Eine Mail-Vorlage mit dem Namen {name} gibt es bereits");
        }
    }
}
