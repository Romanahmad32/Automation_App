using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// EF-Core-Mandantenregister. ID-Vergabe (max+1), Namens-Dublettenprüfung und
/// „ein Ordner, ein Mandant" laufen serverseitig.
///
/// Alleiniger Schreiber zu sein genügt dafür <b>nicht</b>: Zwei Anfragen, die
/// sich überschneiden (Ablage im Word-Reiter, Zuordnung an der Karte), prüften
/// beide gegen denselben Stand und schrieben dann beide. Jede schreibende
/// Methode liest und schreibt deshalb in <b>einer</b> Transaktion.
/// <c>BeginTransactionAsync</c> ist bei Microsoft.Data.Sqlite ein
/// <c>BEGIN IMMEDIATE</c>: Die Schreibsperre fällt schon beim Öffnen, die zweite
/// Anfrage wartet, bis die erste fertig ist, und prüft dann gegen deren Ergebnis.
/// </summary>
public sealed class MandantenRepository(
    AutomationDbContext db,
    IOrdnerStatusRegister ordnerStatus) : IMandantenRepository
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
        await using var transaktion = await db.Database.BeginTransactionAsync(cancellationToken);

        var bestand = await MandantenBestand.LadeAsync(db, cancellationToken);
        var ordner = MandantListen.Lies(neu.AktenOrdnernamenJson);
        bestand.PruefeNameFrei(neu.Vorname, neu.Nachname, eigeneId: null);
        bestand.PruefeOrdnerFrei(ordner, eigeneId: null);

        neu.Id = bestand.HoechsteId + 1;
        neu.ErstelltAm = DateTime.Now;

        db.Mandanten.Add(neu);
        await db.SaveChangesAsync(cancellationToken);
        await NimmVermerkeZurueckAsync(ordner, cancellationToken);
        await transaktion.CommitAsync(cancellationToken);
        return neu;
    }

    public async Task<MandantEntity?> UpdateAsync(MandantEntity mandant, CancellationToken cancellationToken = default)
    {
        await using var transaktion = await db.Database.BeginTransactionAsync(cancellationToken);

        var existing = await db.Mandanten
            .FirstOrDefaultAsync(m => m.Id == mandant.Id, cancellationToken);
        if (existing is null) return null;

        var bestand = await MandantenBestand.LadeAsync(db, cancellationToken);
        bestand.PruefeNameFrei(mandant.Vorname, mandant.Nachname, eigeneId: mandant.Id);

        // Nur die Ordner prüfen, die dieser Mandant vorher noch nicht hatte:
        // im Altbestand kann ein Ordner schon zwei Mandanten zugeordnet sein,
        // und die Regel darf nicht verhindern, dass ein solcher Mandant
        // weiter bearbeitet wird (Adresse ändern, Ordner lösen).
        var bisherige = new OrdnernamenMenge(MandantListen.Lies(existing.AktenOrdnernamenJson));
        var neueOrdner = MandantListen.Lies(mandant.AktenOrdnernamenJson)
            .Where(ordner => !bisherige.Enthaelt(ordner))
            .ToList();
        bestand.PruefeOrdnerFrei(neueOrdner, eigeneId: mandant.Id);

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
        await NimmVermerkeZurueckAsync(neueOrdner, cancellationToken);
        await transaktion.CommitAsync(cancellationToken);
        return existing;
    }

    public async Task<MandantEntity?> OrdnerZuordnenAsync(
        int mandantId,
        string ordnername,
        bool nurPruefen,
        CancellationToken cancellationToken = default)
    {
        var name = OrdnernamenMenge.Schluessel(ordnername);
        if (name.Length == 0)
        {
            throw new ArgumentException("Ohne Ordnernamen lässt sich nichts zuordnen.", nameof(ordnername));
        }

        await using var transaktion = await db.Database.BeginTransactionAsync(cancellationToken);

        var mandant = await db.Mandanten.FirstOrDefaultAsync(m => m.Id == mandantId, cancellationToken);
        if (mandant is null) return null;

        // Hat er ihn schon, gibt es nichts zu prüfen — auch dann nicht, wenn
        // derselbe Ordner im Altbestand zusätzlich einem zweiten Mandanten
        // gehört. Sonst ginge die Ablage in die eigene Akte nicht mehr.
        var ordner = MandantListen.Lies(mandant.AktenOrdnernamenJson);
        var hatIhnSchon = new OrdnernamenMenge(ordner).Enthaelt(name);
        if (!hatIhnSchon)
        {
            var bestand = await MandantenBestand.LadeAsync(db, cancellationToken);
            bestand.PruefeOrdnerFrei([name], eigeneId: mandantId);
        }

        if (nurPruefen) return mandant;

        if (!hatIhnSchon)
        {
            mandant.AktenOrdnernamenJson = MandantListen.Schreib([.. ordner, name]);
            await db.SaveChangesAsync(cancellationToken);
        }

        await NimmVermerkeZurueckAsync([name], cancellationToken);
        await transaktion.CommitAsync(cancellationToken);
        return mandant;
    }

    public async Task<MandantEntity?> OrdnerLoesenAsync(
        int mandantId,
        string ordnername,
        CancellationToken cancellationToken = default)
    {
        await using var transaktion = await db.Database.BeginTransactionAsync(cancellationToken);

        var mandant = await db.Mandanten.FirstOrDefaultAsync(m => m.Id == mandantId, cancellationToken);
        if (mandant is null) return null;

        var geloest = new OrdnernamenMenge([ordnername]);
        var ordner = MandantListen.Lies(mandant.AktenOrdnernamenJson);
        var verbleibend = ordner.Where(o => !geloest.Enthaelt(o)).ToList();
        if (verbleibend.Count == ordner.Count) return mandant;

        mandant.AktenOrdnernamenJson = MandantListen.Schreib(verbleibend);
        await db.SaveChangesAsync(cancellationToken);
        await transaktion.CommitAsync(cancellationToken);
        return mandant;
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
    /// Zuordnung sticht Vermerk — wie beim Import (<see cref="MandantenImport"/>).
    /// Bliebe „ohne Mandantenbezug" an einem zugeordneten Ordner stehen, fiele er
    /// nach dem Lösen unter „Beiseitegelegt" statt in den Arbeitsvorrat. Hier und
    /// nicht im Frontend, weil jeder Weg zu einer Zuordnung hier vorbeikommt:
    /// Karte, Stapel, Ablage und der neue Mandant mit vorbelegtem Ordner.
    /// </summary>
    async Task NimmVermerkeZurueckAsync(List<string> ordner, CancellationToken ct)
    {
        if (ordner.Count > 0) await ordnerStatus.SetzeAsync(ordner, status: null, ct);
    }
}
