using AutomationService.Core.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Sachgebiete.Domain.Services;

/// <summary>
/// SQLite-gestützte Umsetzung von <see cref="ISachgebietKatalog"/>. Der Katalog
/// kommt aus dem Seed der Migration und ändert sich zur Laufzeit (noch) nicht —
/// die Pflege in der App ist §7.1 [S] und kommt in einem eigenen Schnitt.
/// </summary>
public sealed class SachgebietKatalog(AutomationDbContext db) : ISachgebietKatalog
{
    public async Task<IReadOnlyList<SachgebietEntity>> GetAllAsync(
        CancellationToken cancellationToken)
        => await db.Sachgebiete
            .AsNoTracking()
            .OrderBy(s => s.Sortierung)
            .ThenBy(s => s.Kuerzel)
            .ToListAsync(cancellationToken);
}
