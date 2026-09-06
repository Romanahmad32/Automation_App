using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// EF-Core-Umsetzung der Paket-Buchführung.
///
/// Der Kern ist die Menge der erledigten Ordner, und die wird <b>einmal je
/// Aufruf</b> geladen — nicht je Paket. Bei rund 4000 Ordnern und einer
/// wachsenden Zahl Pakete wäre das sonst eine Abfrage je Zeile der Übersicht,
/// und die Übersicht ist genau die Seite, die der Anwalt beim Arbeiten offen
/// hat.
/// </summary>
public sealed class ImportPaketBuch(
    AutomationDbContext db,
    IMandantenRepository mandanten,
    IOrdnerStatusRegister ordnerStatus) : IImportPaketBuch
{
    public async Task<IReadOnlyList<ImportPaketStand>> GetAllAsync(
        CancellationToken cancellationToken = default)
    {
        var pakete = await db.ImportPakete
            .AsNoTracking()
            .OrderByDescending(p => p.Nummer)
            .ToListAsync(cancellationToken);

        if (pakete.Count == 0) return [];

        var erledigt = await ErledigteOrdnerAsync(cancellationToken);
        return [.. pakete.Select(paket => new ImportPaketStand(paket, Zaehle(paket, erledigt)))];
    }

    public async Task<ImportPaketStand> NotiereAsync(
        IReadOnlyList<string> ordnernamen,
        CancellationToken cancellationToken = default)
    {
        var namen = Bereinige(ordnernamen);
        if (namen.Count == 0)
        {
            throw new ArgumentException(
                "Ein Arbeitspaket ohne Ordner lässt sich nicht verbuchen.",
                nameof(ordnernamen));
        }

        // Maximum + 1 statt eines Zählers: Als alleiniger Schreiber der
        // Datenbank kann das Backend das ohne Race, und die Nummer bleibt
        // auch dann richtig, wenn eine Zeile von Hand aus der Tabelle fällt.
        var hoechste = await db.ImportPakete.MaxAsync(p => (int?)p.Nummer, cancellationToken) ?? 0;

        var paket = new ImportPaketEntity
        {
            Nummer = hoechste + 1,
            GeholtAm = DateTime.UtcNow,
            AnzahlOrdner = namen.Count,
            OrdnernamenJson = MandantListen.Schreib(namen),
        };

        db.ImportPakete.Add(paket);
        await db.SaveChangesAsync(cancellationToken);

        var erledigt = await ErledigteOrdnerAsync(cancellationToken);
        return new ImportPaketStand(paket, Zaehle(paket, erledigt));
    }

    public async Task SchreibeFortschrittAsync(
        int zeilen,
        CancellationToken cancellationToken = default)
    {
        var offene = await db.ImportPakete
            .Where(p => p.EingelesenAm == null)
            .ToListAsync(cancellationToken);

        if (offene.Count == 0) return;

        var erledigt = await ErledigteOrdnerAsync(cancellationToken);
        var jetzt = DateTime.UtcNow;
        var geschlossen = false;

        foreach (var paket in offene)
        {
            if (Zaehle(paket, erledigt) < paket.AnzahlOrdner) continue;
            paket.EingelesenAm = jetzt;
            paket.Zeilen = zeilen;
            geschlossen = true;
        }

        // Ein SaveChanges für alle: Ein Import kann mehrere Pakete auf einmal
        // schließen, und halb verbuchte Pakete wären ein Stand, den niemand
        // erklären kann.
        if (geschlossen) await db.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Die Namen aller Ordner, die nicht mehr im Zuordnungsstapel liegen:
    /// zugeordnet oder vermerkt. Beide Mengen werden zusammen in ein
    /// <see cref="HashSet{T}"/> gelegt, damit das Zählen je Paket eine Frage
    /// an den Arbeitsspeicher bleibt und keine an die Datenbank.
    /// </summary>
    async Task<HashSet<string>> ErledigteOrdnerAsync(CancellationToken ct)
    {
        var erledigt = new HashSet<string>(
            await mandanten.GetAktenOrdnernamenAsync(ct),
            StringComparer.OrdinalIgnoreCase);

        foreach (var vermerk in await ordnerStatus.GetAllAsync(ct))
        {
            // Ein leerer Status wäre eine Zeile ohne Aussage — das Register
            // löscht statt zu leeren, aber verlassen wollen wir uns nicht
            // darauf: „erledigt" ist eine Entscheidung, kein Leerfeld.
            if (!string.IsNullOrWhiteSpace(vermerk.Status)) erledigt.Add(vermerk.Ordnername);
        }

        return erledigt;
    }

    static int Zaehle(ImportPaketEntity paket, HashSet<string> erledigt) =>
        MandantListen.Lies(paket.OrdnernamenJson)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Count(erledigt.Contains);

    static List<string> Bereinige(IEnumerable<string> werte) =>
    [
        .. werte
            .Select(wert => wert.Trim())
            .Where(wert => wert.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase),
    ];
}
