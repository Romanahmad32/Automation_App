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
        await EnsureOrdnerFreiAsync(
            MandantListen.Lies(neu.AktenOrdnernamenJson), eigeneId: null, cancellationToken);

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

        // Nur die Ordner prüfen, die dieser Mandant vorher noch nicht hatte:
        // im Altbestand kann ein Ordner schon zwei Mandanten zugeordnet sein,
        // und die Regel darf nicht verhindern, dass ein solcher Mandant
        // weiter bearbeitet wird (Adresse ändern, Ordner lösen).
        var bisherige = new HashSet<string>(
            MandantListen.Lies(existing.AktenOrdnernamenJson), StringComparer.OrdinalIgnoreCase);
        var neueOrdner = MandantListen.Lies(mandant.AktenOrdnernamenJson)
            .Where(ordner => !bisherige.Contains(ordner));
        await EnsureOrdnerFreiAsync(neueOrdner, eigeneId: mandant.Id, cancellationToken);

        existing.Anrede = mandant.Anrede;
        existing.Vorname = mandant.Vorname;
        existing.Nachname = mandant.Nachname;
        existing.StrasseHausnummer = mandant.StrasseHausnummer;
        existing.Postleitzahl = mandant.Postleitzahl;
        existing.Ort = mandant.Ort;
        existing.EmailAdresse = mandant.EmailAdresse;
        existing.Telefonnummer = mandant.Telefonnummer;
        existing.Notiz = mandant.Notiz;
        existing.PersoenlicheGrussformel = mandant.PersoenlicheGrussformel;
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

    /// <summary>
    /// Wirft, wenn einer der übergebenen Ordner bereits einem anderen
    /// Mandanten gehört. Im Speicher geprüft, weil die Ordner je Mandant als
    /// JSON-Spalte liegen (<see cref="MandantListen.Lies"/>) und sich nicht
    /// per SQL abfragen lassen; Vergleich ohne Rücksicht auf
    /// Groß-/Kleinschreibung, wie im Import (<see cref="MandantenImportLauf"/>).
    /// Getrimmte leere Namen werden übergangen.
    /// </summary>
    async Task EnsureOrdnerFreiAsync(IEnumerable<string> ordnernamen, int? eigeneId, CancellationToken ct)
    {
        var gepruefte = ordnernamen
            .Select(ordner => ordner.Trim())
            .Where(ordner => ordner.Length > 0)
            .ToList();
        if (gepruefte.Count == 0) return;

        var andere = await db.Mandanten
            .Where(m => m.Id != eigeneId)
            .Select(m => new { m.Vorname, m.Nachname, m.AktenOrdnernamenJson })
            .ToListAsync(ct);

        foreach (var ordner in gepruefte)
        {
            var inhaber = andere.FirstOrDefault(m => MandantListen.Lies(m.AktenOrdnernamenJson)
                .Contains(ordner, StringComparer.OrdinalIgnoreCase));
            if (inhaber is null) continue;

            var anzeige = MandantName.Anzeige(inhaber.Vorname, inhaber.Nachname);
            var besitzer = anzeige.Length == 0 ? "einem anderen Mandanten" : anzeige;
            throw new MandantOrdnerConflictException(
                $"Der Ordner „{ordner}“ gehört bereits {besitzer} — " +
                "ein Ordner kann nur einem Mandanten zugeordnet sein.");
        }
    }
}
