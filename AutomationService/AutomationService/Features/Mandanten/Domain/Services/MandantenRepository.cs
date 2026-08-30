using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// EF-Core-Mandantenregister. ID-Vergabe (max+1) und Namens-Dublettenprüfung
/// laufen serverseitig — als einziger Schreiber kann das Backend beides ohne
/// Race garantieren.
/// </summary>
public sealed class MandantenRepository(AutomationDbContext db) : IMandantenRepository
{
    /// <summary>Größe eines Ausschnitts, wenn der Aufrufer keine nennt.</summary>
    public const int SeitenGroesse = 50;

    public async Task<IReadOnlyList<MandantEntity>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await db.Mandanten
            .OrderByDescending(m => m.ErstelltAm)
            .ToListAsync(cancellationToken);
    }

    public async Task<MandantenSeite> GetSeiteAsync(
        string? suche,
        int ueberspringen,
        int anzahl,
        CancellationToken cancellationToken = default)
    {
        var treffer = Suche(db.Mandanten, suche);

        var mandanten = await treffer
            // Die zweite Sortierstufe ist nicht Zierde: ein Import legt
            // tausende Mandanten in derselben Sekunde an. Bei gleichem
            // ErstelltAm wäre die Reihenfolge sonst dem SQLite überlassen, und
            // zwei Seitenabrufe teilten den Bestand verschieden auf — Zeilen
            // erschienen doppelt und andere nie.
            .OrderByDescending(m => m.ErstelltAm)
            .ThenByDescending(m => m.Id)
            .Skip(Math.Max(0, ueberspringen))
            .Take(anzahl > 0 ? anzahl : SeitenGroesse)
            .ToListAsync(cancellationToken);

        return new MandantenSeite(
            mandanten,
            Gesamt: await db.Mandanten.CountAsync(cancellationToken),
            Gefiltert: await treffer.CountAsync(cancellationToken));
    }

    public async Task<IReadOnlyList<string>> GetAktenOrdnernamenAsync(
        CancellationToken cancellationToken = default)
    {
        var spalten = await db.Mandanten
            .Select(m => m.AktenOrdnernamenJson)
            .ToListAsync(cancellationToken);

        return
        [
            .. spalten
                .SelectMany(MandantListen.Lies)
                .Distinct(StringComparer.OrdinalIgnoreCase),
        ];
    }

    /// <summary>
    /// Freitextsuche über Name, Ort und die zugeordneten Ordner. Der Name wird
    /// zusammengesetzt verglichen, damit „Max Mustermann" trifft, was in zwei
    /// Spalten steht.
    ///
    /// Die Ordner liegen als JSON-Text in einer Spalte und werden auch als
    /// solcher durchsucht — für Ordnernamen genügt das; einen Suchbegriff mit
    /// Anführungszeichen oder Rückstrich fände es nicht, weil JSON sie
    /// maskiert. Groß-/Kleinschreibung übergeht SQLites LIKE von sich aus,
    /// allerdings nur bei ASCII: „Über" und „über" sind ihm zwei Wörter.
    /// </summary>
    static IQueryable<MandantEntity> Suche(IQueryable<MandantEntity> quelle, string? suche)
    {
        var begriff = (suche ?? string.Empty).Trim();
        if (begriff.Length == 0) return quelle;

        const string maskierung = "\\";
        var muster = "%" + begriff
            .Replace(maskierung, maskierung + maskierung)
            .Replace("%", maskierung + "%")
            .Replace("_", maskierung + "_") + "%";

        return quelle.Where(m =>
            EF.Functions.Like(m.Vorname + " " + m.Nachname, muster, maskierung) ||
            EF.Functions.Like(m.Ort, muster, maskierung) ||
            EF.Functions.Like(m.AktenOrdnernamenJson, muster, maskierung));
    }

    public async Task<MandantEntity> CreateAsync(MandantEntity neu, CancellationToken cancellationToken = default)
    {
        await EnsureNameUniqueAsync(neu.Vorname, neu.Nachname, eigeneId: null, cancellationToken);

        var maxId = await db.Mandanten.AnyAsync(cancellationToken)
            ? await db.Mandanten.MaxAsync(m => m.Id, cancellationToken)
            : 0;
        neu.Id = maxId + 1;
        neu.ErstelltAm = DateTime.Now;

        db.Mandanten.Add(neu);
        await db.SaveChangesAsync(cancellationToken);
        return neu;
    }

    public async Task<MandantEntity?> UpdateAsync(MandantEntity mandant, CancellationToken cancellationToken = default)
    {
        var existing = await db.Mandanten
            .FirstOrDefaultAsync(m => m.Id == mandant.Id, cancellationToken);
        if (existing is null) return null;

        await EnsureNameUniqueAsync(mandant.Vorname, mandant.Nachname, eigeneId: mandant.Id, cancellationToken);

        existing.Anrede = mandant.Anrede;
        existing.Vorname = mandant.Vorname;
        existing.Nachname = mandant.Nachname;
        existing.StrasseHausnummer = mandant.StrasseHausnummer;
        existing.Postleitzahl = mandant.Postleitzahl;
        existing.Ort = mandant.Ort;
        existing.EmailAdresse = mandant.EmailAdresse;
        existing.Telefonnummer = mandant.Telefonnummer;
        existing.Notiz = mandant.Notiz;
        existing.AktenOrdnernamenJson = mandant.AktenOrdnernamenJson;
        existing.KennzeichenJson = mandant.KennzeichenJson;
        // ErstelltAm bleibt unverändert.

        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    public async Task<bool> DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var existing = await db.Mandanten.FirstOrDefaultAsync(m => m.Id == id, cancellationToken);
        if (existing is null) return false;

        db.Mandanten.Remove(existing);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    /// <summary>
    /// Wirft, wenn ein anderer Mandant denselben normalisierten Namen (Vor- +
    /// Nachname, getrimmt/kleingeschrieben) trägt. Namenlose Datensätze sind erlaubt.
    /// </summary>
    async Task EnsureNameUniqueAsync(string vorname, string nachname, int? eigeneId, CancellationToken ct)
    {
        var norm = MandantName.Normalisiere(vorname, nachname);
        if (norm.Length == 0) return;

        // In-Memory normalisieren, weil SQLite Trim/Lower nicht identisch abbildet.
        var alle = await db.Mandanten
            .Select(m => new { m.Id, m.Vorname, m.Nachname })
            .ToListAsync(ct);

        var konflikt = alle.Any(m =>
            m.Id != eigeneId && MandantName.Normalisiere(m.Vorname, m.Nachname) == norm);

        if (konflikt)
        {
            var anzeige = MandantName.Anzeige(vorname, nachname);
            throw new MandantNameConflictException(
                $"Ein Mandant mit dem Namen „{anzeige}“ ist bereits vorhanden.");
        }
    }
}
