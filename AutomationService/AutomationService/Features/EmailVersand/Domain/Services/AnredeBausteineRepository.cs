using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// EF-Core-Repository der Anredeanfänge. Id-Vergabe (max+1) und Eindeutigkeit
/// laufen serverseitig — dieselbe Aufteilung wie bei den Grußformeln
/// (<see cref="GrussformelnRepository"/>).
/// </summary>
public sealed class AnredeBausteineRepository(AutomationDbContext db)
    : IAnredeBausteineRepository
{
    public async Task<IReadOnlyList<AnredeBausteinEntity>> GetAllAsync(
        CancellationToken cancellationToken = default)
        => await db.AnredeBausteine
            .AsNoTracking()
            .OrderBy(a => a.Sortierung)
            .ThenBy(a => a.Maennlich)
            .ToListAsync(cancellationToken);

    public async Task<AnredeBausteinEntity> CreateAsync(
        AnredeBausteinEntity neu,
        CancellationToken cancellationToken = default)
    {
        Bereinige(neu);
        await EnsureUniqueAsync(neu, eigeneId: null, cancellationToken);

        var vorhanden = await db.AnredeBausteine.AnyAsync(cancellationToken);
        neu.Id = vorhanden
            ? await db.AnredeBausteine.MaxAsync(a => a.Id, cancellationToken) + 1
            : 1;

        // Ans Ende, wenn nichts vorgegeben ist: Ein neuer Anfang soll die
        // gewohnte Reihenfolge der vorhandenen nicht durcheinanderbringen.
        if (neu.Sortierung == 0)
        {
            neu.Sortierung = vorhanden
                ? await db.AnredeBausteine.MaxAsync(a => a.Sortierung, cancellationToken) + 10
                : 10;
        }

        db.AnredeBausteine.Add(neu);
        await db.SaveChangesAsync(cancellationToken);
        return neu;
    }

    public async Task<AnredeBausteinEntity?> UpdateAsync(
        AnredeBausteinEntity baustein,
        CancellationToken cancellationToken = default)
    {
        var existing = await db.AnredeBausteine
            .FirstOrDefaultAsync(a => a.Id == baustein.Id, cancellationToken);
        if (existing is null) return null;

        Bereinige(baustein);
        await EnsureUniqueAsync(baustein, eigeneId: baustein.Id, cancellationToken);

        existing.Maennlich = baustein.Maennlich;
        existing.Weiblich = baustein.Weiblich;
        existing.Neutral = baustein.Neutral;
        if (baustein.Sortierung != 0) existing.Sortierung = baustein.Sortierung;

        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var existing = await db.AnredeBausteine
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
        if (existing is null) return false;

        db.AnredeBausteine.Remove(existing);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    /// <summary>
    /// Schneidet Leerraum ab und besteht darauf, dass alle drei Formen
    /// dastehen. Ein Anredeanfang ohne Wortlaut ist keine Einstellung, sondern
    /// eine Lücke, die jede Mail erbt — siehe
    /// <see cref="AnredeBausteinUngueltigException"/>.
    /// </summary>
    static void Bereinige(AnredeBausteinEntity baustein)
    {
        baustein.Maennlich = baustein.Maennlich?.Trim() ?? string.Empty;
        baustein.Weiblich = baustein.Weiblich?.Trim() ?? string.Empty;
        baustein.Neutral = baustein.Neutral?.Trim() ?? string.Empty;

        var fehlend = new List<string>();
        if (baustein.Maennlich.Length == 0) fehlend.Add("maennlich");
        if (baustein.Weiblich.Length == 0) fehlend.Add("weiblich");
        if (baustein.Neutral.Length == 0) fehlend.Add("neutral");
        if (fehlend.Count == 0) return;

        throw new AnredeBausteinUngueltigException(
            $"Der Anredeanfang braucht alle drei Formen; leer ist: {string.Join(", ", fehlend)}");
    }

    async Task EnsureUniqueAsync(AnredeBausteinEntity kandidat, int? eigeneId, CancellationToken ct)
    {
        // Bewusst getrennt: `a.Id != eigeneId` mit eigeneId == null würde EF zu
        // `Id <> NULL` übersetzen (SQL-Unknown) und nie treffen.
        var gleich = db.AnredeBausteine.Where(a =>
            a.Maennlich == kandidat.Maennlich
            && a.Weiblich == kandidat.Weiblich
            && a.Neutral == kandidat.Neutral);

        var konflikt = eigeneId is null
            ? await gleich.AnyAsync(ct)
            : await gleich.AnyAsync(a => a.Id != eigeneId.Value, ct);
        if (konflikt)
        {
            throw new AnredeBausteinConflictException(
                $"Den Anredeanfang \"{kandidat.Maennlich}\" gibt es bereits");
        }
    }
}
