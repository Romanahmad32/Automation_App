using System.Text.RegularExpressions;
using AutomationService.Core.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// EF-Core-Repository der Vorgänge. Upsert/Delete gehen über die Referenz
/// (Unique-Index) und betreffen genau eine Zeile — der entscheidende Unterschied
/// zum früheren JSON-Speicher, der bei jeder Änderung die komplette Liste neu
/// schrieb.
/// </summary>
public sealed partial class VorgangRepository(AutomationDbContext db) : IVorgangRepository
{
    public async Task<IReadOnlyList<VorgangEntity>> GetAllAsync(
        string? status = null,
        string? jahr = null,
        CancellationToken cancellationToken = default)
    {
        var query = db.Vorgaenge.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status)) query = query.Where(v => v.Status == status);
        if (!string.IsNullOrWhiteSpace(jahr)) query = query.Where(v => v.Jahr == jahr);

        return await query
            .OrderByDescending(v => v.AngefragtAm)
            .ToListAsync(cancellationToken);
    }

    public async Task<VorgangEntity?> GetByReferenzAsync(string referenz, CancellationToken cancellationToken = default)
    {
        var bereinigt = referenz.Trim();
        return await db.Vorgaenge.FirstOrDefaultAsync(v => v.Referenz == bereinigt, cancellationToken);
    }

    public async Task<IReadOnlyList<VorgangEntity>> FindeAngefragteZuUnfallAsync(
        string kennzeichen,
        string unfallDatum,
        CancellationToken cancellationToken = default)
    {
        var gesuchtesKennzeichen = ZentralrufReplyParser.NormalizeKennzeichen(kennzeichen);
        var gesuchtesDatum = unfallDatum.Trim();
        if (string.IsNullOrEmpty(gesuchtesKennzeichen) || gesuchtesDatum.Length == 0)
        {
            return [];
        }

        // Kennzeichen-Normalisierung ist nicht in SQL abbildbar — die angefragten
        // Vorgänge sind wenige, der Feinvergleich läuft im Speicher.
        var angefragte = await db.Vorgaenge
            .Where(v => v.Status == "angefragt" && v.Kennzeichen != null && v.UnfallDatum != null)
            .ToListAsync(cancellationToken);

        return angefragte
            .Where(v =>
                ZentralrufReplyParser.NormalizeKennzeichen(v.Kennzeichen) == gesuchtesKennzeichen
                && v.UnfallDatum!.Trim() == gesuchtesDatum)
            .ToList();
    }

    public async Task<VorgangEntity> UpsertAsync(VorgangEntity vorgang, CancellationToken cancellationToken = default)
    {
        vorgang.Referenz = vorgang.Referenz.Trim();
        var existing = await db.Vorgaenge
            .FirstOrDefaultAsync(v => v.Referenz == vorgang.Referenz, cancellationToken);

        if (existing is null)
        {
            db.Vorgaenge.Add(vorgang);
            await db.SaveChangesAsync(cancellationToken);
            return vorgang;
        }

        CopyInto(existing, vorgang);
        await db.SaveChangesAsync(cancellationToken);
        return existing;
    }

    public async Task<bool> DeleteAsync(string referenz, CancellationToken cancellationToken = default)
    {
        var bereinigt = referenz.Trim();
        var existing = await db.Vorgaenge.FirstOrDefaultAsync(v => v.Referenz == bereinigt, cancellationToken);
        if (existing is null) return false;

        db.Vorgaenge.Remove(existing);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<VorgangEntity?> SetzeEntwurfAsync(
        string referenz,
        string? entwurfJson,
        CancellationToken cancellationToken = default)
    {
        var bereinigt = referenz.Trim();
        var vorgang = await db.Vorgaenge.FirstOrDefaultAsync(v => v.Referenz == bereinigt, cancellationToken);
        if (vorgang is null) return null;

        vorgang.EntwurfJson = string.IsNullOrWhiteSpace(entwurfJson) ? null : entwurfJson;
        await db.SaveChangesAsync(cancellationToken);
        return vorgang;
    }

    public async Task<ReferenzAenderung> RenameReferenzAsync(
        string von,
        string nach,
        CancellationToken cancellationToken = default)
    {
        var alteReferenz = von.Trim();
        var neueReferenz = nach.Trim();

        var vorgang = await db.Vorgaenge
            .FirstOrDefaultAsync(v => v.Referenz == alteReferenz, cancellationToken);
        if (vorgang is null) return new ReferenzAenderung(ReferenzAenderungStatus.NichtGefunden);
        if (neueReferenz == alteReferenz) return new ReferenzAenderung(ReferenzAenderungStatus.Geaendert, vorgang);

        // Konfliktprüfung wie der Frontend-Vergleich tolerant gegenüber
        // Groß-/Kleinschreibung (die Referenz ist der fachliche Schlüssel).
        var neueReferenzGross = neueReferenz.ToUpperInvariant();

        // v.Referenz.ToUpper() steht in einem Ausdrucksbaum und wird von EF Core
        // zu SQL UPPER() übersetzt — der Aufruf läuft nie in .NET, die von
        // CA1304/CA1862 gemeinte Kulturabhängigkeit gibt es hier also nicht.
        // string.Equals(…, StringComparison) wäre der empfohlene Ersatz, kann
        // vom SQLite-Provider aber nicht übersetzt werden und würde zur
        // Laufzeit fehlschlagen.
#pragma warning disable CA1304, CA1311, CA1862
        var vergeben = await db.Vorgaenge.AnyAsync(
            v => v.Id != vorgang.Id && v.Referenz.ToUpper() == neueReferenzGross,
            cancellationToken);
#pragma warning restore CA1304, CA1311, CA1862
        if (vergeben) return new ReferenzAenderung(ReferenzAenderungStatus.Vergeben);

        vorgang.Referenz = neueReferenz;
        UebernehmeReferenzTeile(vorgang);
        await db.SaveChangesAsync(cancellationToken);
        return new ReferenzAenderung(ReferenzAenderungStatus.Geaendert, vorgang);
    }

    /// <summary>
    /// Leitet die Bestandteile (Nr/Jahr/Abteilung/Kennzeichen) neu aus der
    /// Referenz ab — Schema "Nr/Jahr Abteilung_Kennzeichen" wie im Frontend
    /// (ReferenzTeile.parse). Passt die Referenz nicht ins Schema, werden die
    /// Spalten geleert, damit kein veraltetes Aktenzeichen stehen bleibt.
    /// </summary>
    static void UebernehmeReferenzTeile(VorgangEntity vorgang)
    {
        var match = ReferenzSchemaRegex().Match(vorgang.Referenz);
        if (match.Success)
        {
            vorgang.LaufendeNummer = int.TryParse(match.Groups[1].Value, out var nummer) ? nummer : null;
            vorgang.Jahr = match.Groups[2].Value;
            vorgang.Abteilung = match.Groups[3].Value;
            vorgang.Kennzeichen = match.Groups[4].Value.Trim();
        }
        else
        {
            vorgang.LaufendeNummer = null;
            vorgang.Jahr = null;
            vorgang.Abteilung = null;
            vorgang.Kennzeichen = null;
        }
    }

    [GeneratedRegex(@"^\s*(\d+)\s*/\s*(\d+)\s+(\S+)_(.+)$")]
    private static partial Regex ReferenzSchemaRegex();

    /// <summary>Übernimmt alle fachlichen Felder (ohne Id/Referenz) in die getrackte Zeile.</summary>
    static void CopyInto(VorgangEntity target, VorgangEntity source)
    {
        target.AngefragtAm = source.AngefragtAm;
        target.Status = source.Status;
        target.Rechtsgebiet = source.Rechtsgebiet;
        target.LaufendeNummer = source.LaufendeNummer;
        target.Jahr = source.Jahr;
        target.Abteilung = source.Abteilung;
        target.Kennzeichen = source.Kennzeichen;
        target.MandantId = source.MandantId;
        target.MandantName = source.MandantName;
        target.Gegner = source.Gegner;
        target.UnfallDatum = source.UnfallDatum;
        target.GeschaedigtenKennzeichen = source.GeschaedigtenKennzeichen;
        target.Unfallort = source.Unfallort;
        target.Unfalluhrzeit = source.Unfalluhrzeit;
        target.PolizeiVorgangsnummer = source.PolizeiVorgangsnummer;
        target.AntwortJson = source.AntwortJson;
        target.FeldWerteJson = source.FeldWerteJson;
        target.SchadensaufstellungJson = source.SchadensaufstellungJson;
        target.EntwurfJson = source.EntwurfJson;
        target.SchreibenNummer = source.SchreibenNummer;
        target.DokumentPfad = source.DokumentPfad;
        target.AktenOrdner = source.AktenOrdner;
        target.AbgeschlossenAm = source.AbgeschlossenAm;
    }
}
