using AutomationService.Core.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Führt einen Mandantenimport aus. Prüflauf und Übernahme sind derselbe Code
/// und unterscheiden sich in einer einzigen Verzweigung am Ende — die Vorschau
/// zeigt deshalb, was passiert, und nicht eine zweite Auslegung der Regeln.
///
/// Geschrieben wird in <b>einer</b> Transaktion und mit <b>einem</b>
/// SaveChanges für alle Mandanten. Über <c>MandantenRepository.CreateAsync</c>
/// zu gehen wäre naheliegend, wäre bei viertausend Zeilen aber viertausend
/// Speichervorgänge und viertausend Dublettenprüfungen über den ganzen Bestand.
/// </summary>
public sealed class MandantenImport(AutomationDbContext db, IOrdnerStatusRegister ordnerStatus)
    : IMandantenImport
{
    public async Task<MandantenImportBefund> FuehreAusAsync(
        MandantenImportAuftrag auftrag,
        CancellationToken cancellationToken = default)
    {
        // Im Prüflauf werden dieselben Entitäten verändert wie beim Schreiben.
        // Ungetrackt geladen kann daraus auch dann nichts in die Datenbank
        // gelangen, wenn später jemand ein SaveChanges danebenstellt.
        var register = auftrag.NurPruefen
            ? await db.Mandanten.AsNoTracking().ToListAsync(cancellationToken)
            : await db.Mandanten.ToListAsync(cancellationToken);

        // Die schon gesetzten Vermerke gehören zum Ausgangsstand: ohne sie
        // zählte ein zweiter Lauf derselben Datei dieselben Ordner erneut als
        // „ohne Mandantenbezug" und behauptete eine Wirkung, die es nicht gibt.
        var vermerkt = await ordnerStatus.GetAllAsync(cancellationToken);
        var lauf = new MandantenImportLauf(register, vermerkt.Select(o => o.Ordnername));
        for (var zeile = 0; zeile < auftrag.Mandanten.Count; zeile++)
        {
            lauf.Verarbeite(zeile, auftrag.Mandanten[zeile]);
        }

        lauf.MarkiereOhneBezug(auftrag.OhneMandantenbezug);

        if (auftrag.NurPruefen) return lauf.Ergebnis(angewendet: false);

        await SchreibeAsync(lauf, cancellationToken);
        return lauf.Ergebnis(angewendet: true);
    }

    async Task SchreibeAsync(MandantenImportLauf lauf, CancellationToken cancellationToken)
    {
        await using var transaktion = await db.Database.BeginTransactionAsync(cancellationToken);

        db.Mandanten.AddRange(lauf.NeueMandanten);
        await db.SaveChangesAsync(cancellationToken);

        if (lauf.ZugeordneteOrdner.Count > 0)
        {
            await ordnerStatus.SetzeAsync([.. lauf.ZugeordneteOrdner], null, cancellationToken);
        }

        if (lauf.Markierte.Count > 0)
        {
            await ordnerStatus.SetzeAsync(
                [.. lauf.Markierte],
                OrdnerStatusArten.OhneMandantenbezug,
                cancellationToken);
        }

        await transaktion.CommitAsync(cancellationToken);
    }
}
