using AutomationService.Core.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Führt einen Registerimport aus (§6.2). Prüflauf und Übernahme sind derselbe
/// Code und unterscheiden sich in einer einzigen Verzweigung am Ende — die
/// Vorschau zeigt deshalb, was passiert, und nicht eine zweite Auslegung der
/// Regeln.
///
/// Der Bestand wird immer ungetrackt gelesen: Der Import ändert keine einzige
/// gespeicherte Zeile, er legt nur neue an. Damit kann aus dem Prüflauf auch
/// dann nichts in die Datenbank gelangen, wenn später jemand ein SaveChanges
/// danebenstellt.
/// </summary>
public sealed class RegisterImport(AutomationDbContext db, ISachgebietKatalog katalog) : IRegisterImport
{
    public async Task<RegisterImportBefund> FuehreAusAsync(
        RegisterImportAuftrag auftrag,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(auftrag);

        var nachschlag = new SachgebietNachschlag(await katalog.GetAllAsync(cancellationToken));
        var bestand = await BestandAsync(auftrag, cancellationToken);
        var jetzt = DateTime.UtcNow;

        var befunde = new List<JahrgangBefund>();
        var neue = new List<RegisterHistorieEntity>();

        foreach (var jahrgang in auftrag.Jahrgaenge)
        {
            var lauf = new JahrgangImportLauf(
                jahrgang, bestand.GetValueOrDefault(jahrgang.Jahrgang, []), nachschlag, jetzt);

            // Je Jahrgang von 1 an: Die Oberfläche spricht eine Zeile als
            // (Jahrgang, Zeile) an, weil der Anwalt jahrgangsweise prüft und
            // freigibt. Eine über die ganze Datei durchlaufende Nummer wäre in
            // der Befundkarte eines Jahrgangs eine Zahl ohne Bezug.
            var zeileImJahrgang = 0;
            foreach (var zeile in jahrgang.Zeilen)
            {
                lauf.Verarbeite(++zeileImJahrgang, zeile);
            }

            befunde.Add(lauf.Ergebnis());
            neue.AddRange(lauf.NeueZeilen);
        }

        if (auftrag.NurPruefen) return new RegisterImportBefund(befunde, Angewendet: false);

        await SchreibeAsync(neue, cancellationToken);
        return new RegisterImportBefund(befunde, Angewendet: true);
    }

    /// <summary>
    /// Die schon gespeicherten Zeilen der betroffenen Jahrgänge, je Jahr — als
    /// Tripel aus Nummer, Zusatz und Freitext.
    ///
    /// Nur die Jahrgänge der Datei: Der Bestand kann Tausende Zeilen umfassen,
    /// gebraucht wird davon nur die Wiedererkennungsmenge. Ohne sie meldete das
    /// Einlesen einer Nachlieferung jede früher übernommene Nummer als Lücke.
    /// Der Freitext geht mit, obwohl <c>JahrgangImportLauf</c> ihn nur für
    /// nummernlose Zeilen braucht (<c>(Nummer, Zusatz)</c> ist dort kein
    /// eindeutiger Schlüssel) — ihn nur für diese gesondert nachzuladen wäre
    /// die aufwendigere Abfrage für den selteneren Fall.
    /// </summary>
    async Task<Dictionary<int, List<(int Nummer, string Zusatz, string Freitext)>>> BestandAsync(
        RegisterImportAuftrag auftrag,
        CancellationToken cancellationToken)
    {
        var jahre = auftrag.Jahrgaenge.Select(jahrgang => jahrgang.Jahrgang).Distinct().ToList();
        if (jahre.Count == 0) return [];

        var vorhanden = await db.RegisterHistorie
            .AsNoTracking()
            .Where(zeile => jahre.Contains(zeile.Jahr))
            .Select(zeile => new { zeile.Jahr, zeile.LaufendeNummer, zeile.NummerZusatz, zeile.Freitext })
            .ToListAsync(cancellationToken);

        return vorhanden
            .GroupBy(zeile => zeile.Jahr)
            .ToDictionary(
                gruppe => gruppe.Key,
                gruppe => gruppe.Select(z => (z.LaufendeNummer, z.NummerZusatz, z.Freitext)).ToList());
    }

    /// <summary>
    /// Alles oder nichts. Ein halb übernommener Jahrgang wäre der schlechteste
    /// Zustand von allen: Er sieht im Stand vollständig aus und hat Lücken, die
    /// niemand mehr einer Ursache zuordnen kann.
    /// </summary>
    async Task SchreibeAsync(
        List<RegisterHistorieEntity> neue,
        CancellationToken cancellationToken)
    {
        if (neue.Count == 0) return;

        await using var transaktion = await db.Database.BeginTransactionAsync(cancellationToken);
        db.RegisterHistorie.AddRange(neue);
        await db.SaveChangesAsync(cancellationToken);
        await transaktion.CommitAsync(cancellationToken);
    }
}
