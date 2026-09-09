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
public sealed class MandantenImport(
    AutomationDbContext db,
    IOrdnerStatusRegister ordnerStatus,
    IImportPaketBuch paketBuch,
    ILogger<MandantenImport> logger) : IMandantenImport
{
    public async Task<MandantenImportBefund> FuehreAusAsync(
        MandantenImportAuftrag auftrag,
        CancellationToken cancellationToken = default)
    {
        if (auftrag.NurPruefen)
        {
            var pruefLauf = await BaueLaufAsync(auftrag, tracking: false, cancellationToken);
            return pruefLauf.Ergebnis(angewendet: false);
        }

        // Registerstand und Schreiben liegen in derselben Transaktion: Läge das
        // Lesen davor, könnte zwischen Prüfung und Schreiben ein anderer
        // Schreibzugriff (z. B. ein von Hand angelegter Mandant) dazwischenkommen,
        // den der Import nicht mehr sähe — er legte dann eine Dublette an, die
        // das Register selbst mit 409 abgelehnt hätte.
        await using var transaktion = await db.Database.BeginTransactionAsync(cancellationToken);

        var lauf = await BaueLaufAsync(auftrag, tracking: true, cancellationToken);
        await SchreibeAsync(lauf, cancellationToken);

        await transaktion.CommitAsync(cancellationToken);

        await VerbucheFortschrittAsync(auftrag.Mandanten.Count, cancellationToken);
        return lauf.Ergebnis(angewendet: true);
    }

    async Task<MandantenImportLauf> BaueLaufAsync(
        MandantenImportAuftrag auftrag, bool tracking, CancellationToken cancellationToken)
    {
        // Im Prüflauf werden dieselben Entitäten verändert wie beim Schreiben.
        // Ungetrackt geladen kann daraus auch dann nichts in die Datenbank
        // gelangen, wenn später jemand ein SaveChanges danebenstellt.
        var register = tracking
            ? await db.Mandanten.ToListAsync(cancellationToken)
            : await db.Mandanten.AsNoTracking().ToListAsync(cancellationToken);

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
        return lauf;
    }

    /// <summary>
    /// Trägt nach, welche Arbeitspakete dieser Import geschlossen hat.
    ///
    /// Bewusst <b>außerhalb</b> der Transaktion und hinter einem Fangnetz: Der
    /// Import ist die Hauptsache, die Buchführung die Nebensache. Wären beide
    /// verbunden, machte ein Fehler in der Nebensache die viertausend soeben
    /// geschriebenen Mandanten wieder zunichte — oder meldete dem Anwalt einen
    /// Fehlschlag, den es nicht gab, und ließe ihn dieselbe Datei ein zweites
    /// Mal einlesen. Ein nicht geschlossenes Paket kostet dagegen nichts: Der
    /// erledigt-Zähler wird bei jedem Lesen neu gerechnet und zeigt den
    /// Fortschritt auch dann richtig an.
    /// </summary>
    async Task VerbucheFortschrittAsync(int zeilen, CancellationToken cancellationToken)
    {
        try
        {
            await paketBuch.SchreibeFortschrittAsync(zeilen, cancellationToken);
        }
        catch (Exception ausnahme) when (ausnahme is not OperationCanceledException)
        {
            logger.LogWarning(
                ausnahme,
                "Der Import über {Zeilen} Zeilen ist geschrieben, die Arbeitspakete " +
                "ließen sich aber nicht fortschreiben.",
                zeilen);
        }
    }

    async Task SchreibeAsync(MandantenImportLauf lauf, CancellationToken cancellationToken)
    {
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
    }
}
