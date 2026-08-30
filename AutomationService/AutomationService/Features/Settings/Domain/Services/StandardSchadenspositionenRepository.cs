using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// EF-Core-Repository der Standardpositionen. Die Tabelle hält nur, was der
/// Anwalt selbst hinterlegt hat: Solange sie leer ist, kommt die Vorgabe aus
/// dem Code (<see cref="StandardSchadenspositionenVorgabe"/>) — so bleibt
/// „nicht konfiguriert" von „bewusst so konfiguriert" unterscheidbar, und ein
/// Speichern der leeren Liste ist zugleich das Zurücksetzen.
/// </summary>
public sealed class StandardSchadenspositionenRepository(AutomationDbContext db)
    : IStandardSchadenspositionenRepository
{
    public async Task<IReadOnlyList<StandardSchadenspositionEntity>> GetAsync(
        CancellationToken cancellationToken = default)
    {
        var gespeichert = await db.StandardSchadenspositionen
            .OrderBy(p => p.Reihenfolge)
            .ThenBy(p => p.Id)
            .ToListAsync(cancellationToken);

        return gespeichert.Count > 0 ? gespeichert : Vorgabe();
    }

    public async Task<IReadOnlyList<StandardSchadenspositionEntity>> SaveAsync(
        IReadOnlyList<StandardSchadenspositionEntity> positionen,
        CancellationToken cancellationToken = default)
    {
        // Zeilen ohne Bezeichnung fallen heraus: Eine leere Zeile im Editor ist
        // keine Position, und sie soll das Zurücksetzen (leere Liste) nicht
        // versehentlich zu einer Konfiguration aus lauter Leerzeilen machen.
        var bereinigt = positionen
            .Where(p => !string.IsNullOrWhiteSpace(p.Bezeichnung))
            .ToList();

        // Komplettersatz statt Einzelabgleich: Die Liste ist klein, und die
        // Reihenfolge kommt allein aus der übergebenen Liste.
        db.StandardSchadenspositionen.RemoveRange(db.StandardSchadenspositionen);
        for (var i = 0; i < bereinigt.Count; i++)
        {
            db.StandardSchadenspositionen.Add(new StandardSchadenspositionEntity
            {
                Reihenfolge = i,
                Bezeichnung = bereinigt[i].Bezeichnung.Trim(),
                Betrag = bereinigt[i].Betrag,
            });
        }

        await db.SaveChangesAsync(cancellationToken);
        return await GetAsync(cancellationToken);
    }

    private static List<StandardSchadenspositionEntity> Vorgabe() =>
    [
        .. StandardSchadenspositionenVorgabe.Bezeichnungen.Select((bezeichnung, i) =>
            new StandardSchadenspositionEntity { Reihenfolge = i, Bezeichnung = bezeichnung }),
    ];
}
