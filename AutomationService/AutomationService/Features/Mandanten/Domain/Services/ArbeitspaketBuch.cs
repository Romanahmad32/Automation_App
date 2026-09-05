using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// EF-Core-Umsetzung des Arbeitspaket-Buchs. Dieselbe Bauform wie
/// <see cref="MandantenImport"/>: der Kontext für das Register, das
/// Vermerkregister daneben — ein Paket entsteht aus beidem.
///
/// Die Reihenfolge ist die eigentliche Zusage. Sortiert wird stabil und
/// alphabetisch, damit zwei Sitzungen ohne Import dazwischen <b>dasselbe</b>
/// Paket bekommen und ein abgebrochenes beim nächsten Holen wieder vorn steht.
/// Eine Auswahl nach Zufall oder Einlesereihenfolge wäre für den Erzeuger nicht
/// nachvollziehbar und für den Anwalt nicht prüfbar.
/// </summary>
public sealed class ArbeitspaketBuch(AutomationDbContext db, IOrdnerStatusRegister ordnerStatus)
    : IArbeitspaketBuch
{
    /// <summary>
    /// Grenzen der Paketgröße. Nach unten, weil ein Paket ohne Ordner kein
    /// Paket ist; nach oben, weil ein Paket, das der Erzeuger in einer Sitzung
    /// nicht schafft, genau das Problem zurückbringt, dessentwegen es Pakete
    /// gibt.
    /// </summary>
    public const int KleinstesPaket = 1;

    /// <inheritdoc cref="KleinstesPaket"/>
    public const int GroesstesPaket = 1000;

    public async Task<ArbeitspaketEntity> HoleAsync(
        IReadOnlyList<string> ordnernamen,
        int anzahl,
        CancellationToken cancellationToken = default)
    {
        var erledigt = await ErledigteOrdner.LiesAsync(db, ordnerStatus, cancellationToken);

        var offen = ordnernamen
            .Select(name => name.Trim())
            .Where(name => name.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Where(name => !erledigt.Contains(name))
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .Take(Math.Clamp(anzahl, KleinstesPaket, GroesstesPaket))
            .ToList();

        // Vor der Nummernvergabe, nicht danach: ein leeres Paket verbrauchte
        // sonst eine Nummer und stünde für immer ohne „eingelesen am" in der
        // Historie — genau das Bild, an dem der Anwalt ein fehlendes Paket
        // erkennen soll.
        if (offen.Count == 0)
        {
            throw new KeineOffenenOrdnerException(
                "Es ist kein Ordner mehr offen — es gibt nichts zu holen.");
        }

        // Die Nummer zählt über den Bestand des Buchs, nicht über dessen
        // Zeilenzahl: eine gelöschte Zeile würde sonst eine Nummer ein zweites
        // Mal vergeben, und der Unique-Index schlüge zu.
        var hoechste = await db.Arbeitspakete
            .Select(paket => (int?)paket.Nummer)
            .MaxAsync(cancellationToken) ?? 0;

        var neues = new ArbeitspaketEntity
        {
            Nummer = hoechste + 1,
            GeholtAm = DateTime.Now,
            OrdnernamenJson = MandantListen.Schreib(offen),
        };

        db.Arbeitspakete.Add(neues);
        await db.SaveChangesAsync(cancellationToken);
        return neues;
    }

    public async Task<IReadOnlyList<ArbeitspaketEntity>> GetAllAsync(
        CancellationToken cancellationToken = default)
    {
        return await db.Arbeitspakete
            .OrderByDescending(paket => paket.Nummer)
            .ToListAsync(cancellationToken);
    }

    public async Task MarkiereEingelesenAsync(
        IReadOnlySet<string> erledigteOrdner,
        CancellationToken cancellationToken = default)
    {
        var pakete = await db.Arbeitspakete.ToListAsync(cancellationToken);
        if (pakete.Count == 0) return;

        // Über den Vergleicher der übergebenen Menge entscheidet der Aufrufer;
        // hier gilt derselbe wie überall im Slice. Einmal umgehängt kostet das
        // eine Menge über viertausend Namen und spart einen Fehler, der sich
        // nur an fremd geschriebenen Ordnernamen zeigen würde.
        var erledigt = new HashSet<string>(erledigteOrdner, StringComparer.OrdinalIgnoreCase);
        var jetzt = DateTime.Now;

        foreach (var paket in pakete)
        {
            var treffer = MandantListen.Lies(paket.OrdnernamenJson).Count(erledigt.Contains);
            paket.ErledigtAnzahl = treffer;

            // Neu gerechnet statt aufaddiert, und der Zeitpunkt bleibt beim
            // ersten Mal stehen: derselbe Import ein zweites Mal eingelesen
            // darf am Buch nichts verändern.
            if (treffer > 0 && paket.EingelesenAm is null) paket.EingelesenAm = jetzt;
        }

        await db.SaveChangesAsync(cancellationToken);
    }
}
