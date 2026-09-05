using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Die Ordner, über die entschieden ist: zugeordnet (sie stehen an einem
/// Mandanten) oder vermerkt („ohne Mandantenbezug"). Der Gegenbegriff zu
/// <em>offen</em>.
///
/// Diese eine Rechnung brauchen beide Seiten des Paketbetriebs: das Buch, um zu
/// wissen, welche Ordner ein neues Paket überhaupt enthalten darf, und der
/// Import, um zu melden, wie weit die ausgegebenen Pakete abgearbeitet sind.
/// Zweimal geschrieben liefen die beiden Auslegungen früher oder später
/// auseinander — und dann behauptete das Buch etwas anderes als der Stapel.
/// </summary>
public static class ErledigteOrdner
{
    /// <summary>
    /// Liest den aktuellen Stand aus Register und Vermerken. Verglichen wird
    /// ohne Rücksicht auf Groß- und Kleinschreibung, wie überall, wo hier
    /// Ordnernamen vorkommen: sie stammen aus dem Windows-Dateisystem und
    /// bezeichnen dort denselben Ordner, wie immer sie geschrieben sind.
    /// </summary>
    public static async Task<HashSet<string>> LiesAsync(
        AutomationDbContext db,
        IOrdnerStatusRegister ordnerStatus,
        CancellationToken cancellationToken = default)
    {
        var erledigt = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        // Nur die JSON-Spalte, nicht der ganze Mandant: bei viertausend Zeilen
        // ist das der Unterschied zwischen einer Spalte und dreizehn.
        var listen = await db.Mandanten
            .AsNoTracking()
            .Select(mandant => mandant.AktenOrdnernamenJson)
            .ToListAsync(cancellationToken);

        foreach (var json in listen)
        {
            foreach (var ordner in MandantListen.Lies(json))
            {
                erledigt.Add(ordner);
            }
        }

        foreach (var vermerk in await ordnerStatus.GetAllAsync(cancellationToken))
        {
            erledigt.Add(vermerk.Ordnername);
        }

        return erledigt;
    }
}
