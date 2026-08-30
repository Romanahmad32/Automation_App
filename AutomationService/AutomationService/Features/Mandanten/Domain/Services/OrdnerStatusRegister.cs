using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// EF-Core-Umsetzung der Ordner-Vermerke. Setzen ist ein Upsert je Ordnername,
/// Zurücknehmen ein Löschen — beides in einem <c>SaveChanges</c>, damit eine
/// Massenaktion über hunderte Ordner entweder ganz oder gar nicht wirkt.
/// </summary>
public sealed class OrdnerStatusRegister(AutomationDbContext db) : IOrdnerStatusRegister
{
    public async Task<IReadOnlyList<OrdnerStatusEntity>> GetAllAsync(
        CancellationToken cancellationToken = default)
    {
        return await db.OrdnerStatus
            .OrderBy(o => o.Ordnername)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<OrdnerStatusEntity>> SetzeAsync(
        IReadOnlyList<string> ordnernamen,
        string? status,
        CancellationToken cancellationToken = default)
    {
        if (status is not null && !OrdnerStatusArten.Alle.Contains(status))
        {
            throw new ArgumentException($"Unbekannter Ordnerstatus: {status}", nameof(status));
        }

        // Leere Namen fielen sonst als Geisterzeile in die Tabelle und ließen
        // sich über die Oberfläche nie wieder entfernen.
        var namen = ordnernamen
            .Select(name => name.Trim())
            .Where(name => name.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .ToList();

        if (namen.Count > 0)
        {
            var vorhanden = await db.OrdnerStatus
                .Where(o => namen.Contains(o.Ordnername))
                .ToListAsync(cancellationToken);

            if (status is null)
            {
                db.OrdnerStatus.RemoveRange(vorhanden);
            }
            else
            {
                Uebernimm(namen, vorhanden, status);
            }

            await db.SaveChangesAsync(cancellationToken);
        }

        return await GetAllAsync(cancellationToken);
    }

    void Uebernimm(List<string> namen, List<OrdnerStatusEntity> vorhanden, string status)
    {
        var jetzt = DateTime.Now;
        var bekannt = vorhanden.ToDictionary(o => o.Ordnername, StringComparer.Ordinal);

        foreach (var name in namen)
        {
            if (bekannt.TryGetValue(name, out var eintrag))
            {
                eintrag.Status = status;
                eintrag.GesetztAm = jetzt;
            }
            else
            {
                db.OrdnerStatus.Add(new OrdnerStatusEntity
                {
                    Ordnername = name,
                    Status = status,
                    GesetztAm = jetzt,
                });
            }
        }
    }
}
