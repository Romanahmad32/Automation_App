using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Name und Akten-Ordner aller Mandanten, <b>einmal</b> gelesen — die Grundlage
/// der Prüfungen, bevor <see cref="MandantenRepository"/> schreibt:
/// Namensdublette und schon vergebener Ordner.
///
/// Vorher las jede Prüfung die Tabelle für sich, und die Ordnerprüfung las die
/// JSON-Spalte jedes anderen Mandanten für jeden geprüften Ordner erneut. Bei
/// rund 4000 Mandanten und drei Ordnern waren das zwölftausend
/// Deserialisierungen je Anlage. Jetzt entsteht das Verzeichnis Ordner → Inhaber
/// einmal, und erst dann, wenn wirklich ein Ordner zu prüfen ist.
///
/// Im Speicher geprüft, weil SQLite Trim/Lower nicht wie C# abbildet und die
/// Ordner als JSON-Spalte liegen (<see cref="MandantListen.Lies"/>).
/// </summary>
public sealed class MandantenBestand
{
    readonly IReadOnlyList<Zeile> _zeilen;
    Dictionary<string, List<Zeile>>? _inhaberJeOrdner;

    MandantenBestand(IReadOnlyList<Zeile> zeilen) => _zeilen = zeilen;

    /// <summary>
    /// Liest den Bestand. In einer Transaktion aufrufen, die bis zum Schreiben
    /// offen bleibt — sonst kann zwischen Prüfen und Speichern ein zweiter
    /// Aufruf denselben Ordner vergeben.
    /// </summary>
    public static async Task<MandantenBestand> LadeAsync(AutomationDbContext db, CancellationToken ct)
    {
        var zeilen = await db.Mandanten
            .AsNoTracking()
            .Select(m => new Zeile(m.Id, m.Vorname, m.Nachname, m.AktenOrdnernamenJson))
            .ToListAsync(ct);
        return new MandantenBestand(zeilen);
    }

    /// <summary>Die höchste vergebene ID; 0 bei leerem Register.</summary>
    public int HoechsteId => _zeilen.Count == 0 ? 0 : _zeilen.Max(z => z.Id);

    /// <summary>
    /// Wirft, wenn ein anderer Mandant denselben normalisierten Namen
    /// (<see cref="MandantName.Normalisiere"/>) trägt. Namenlose Datensätze
    /// sind erlaubt.
    /// </summary>
    public void PruefeNameFrei(string vorname, string nachname, int? eigeneId)
    {
        var norm = MandantName.Normalisiere(vorname, nachname);
        if (norm.Length == 0) return;

        var konflikt = _zeilen.Any(z =>
            z.Id != eigeneId && MandantName.Normalisiere(z.Vorname, z.Nachname) == norm);
        if (!konflikt) return;

        var anzeige = MandantName.Anzeige(vorname, nachname);
        throw new MandantNameConflictException(
            $"Ein Mandant mit dem Namen „{anzeige}“ ist bereits vorhanden.");
    }

    /// <summary>
    /// Wirft, wenn einer der Ordner einem anderen Mandanten als
    /// <paramref name="eigeneId"/> gehört. Verglichen wird nach
    /// <see cref="OrdnernamenMenge"/>, leere Namen werden übergangen.
    /// </summary>
    public void PruefeOrdnerFrei(IEnumerable<string> ordnernamen, int? eigeneId)
    {
        foreach (var ordner in ordnernamen.Select(OrdnernamenMenge.Schluessel))
        {
            if (ordner.Length == 0) continue;
            if (!InhaberJeOrdner().TryGetValue(ordner, out var inhaber)) continue;

            // Gehört er im Altbestand zugleich dem eigenen Mandanten, zählt
            // trotzdem nur, ob ein anderer ihn hat.
            var fremd = inhaber.FirstOrDefault(z => z.Id != eigeneId);
            if (fremd is null) continue;

            var anzeige = MandantName.Anzeige(fremd.Vorname, fremd.Nachname);
            var besitzer = anzeige.Length == 0 ? "einem anderen Mandanten" : anzeige;
            throw new MandantOrdnerConflictException(
                $"Der Ordner „{ordner}“ gehört bereits {besitzer} — " +
                "ein Ordner kann nur einem Mandanten zugeordnet sein.");
        }
    }

    /// <summary>
    /// Eine Liste je Ordner und nicht ein Inhaber: Im Altbestand kann ein Ordner
    /// zwei Mandanten gehören (vor der Regel zugeordnet), und welcher davon der
    /// „andere" ist, entscheidet erst der Aufrufer.
    /// </summary>
    Dictionary<string, List<Zeile>> InhaberJeOrdner()
    {
        if (_inhaberJeOrdner is not null) return _inhaberJeOrdner;

        _inhaberJeOrdner = new Dictionary<string, List<Zeile>>(StringComparer.OrdinalIgnoreCase);
        foreach (var zeile in _zeilen)
        {
            var eigene = MandantListen.Lies(zeile.AktenOrdnernamenJson)
                .Select(OrdnernamenMenge.Schluessel)
                .Distinct(StringComparer.OrdinalIgnoreCase);
            foreach (var ordner in eigene)
            {
                if (!_inhaberJeOrdner.TryGetValue(ordner, out var liste))
                {
                    _inhaberJeOrdner[ordner] = liste = [];
                }
                liste.Add(zeile);
            }
        }
        return _inhaberJeOrdner;
    }

    sealed record Zeile(int Id, string Vorname, string Nachname, string AktenOrdnernamenJson);
}
