using AutomationService.Core.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// SQLite-gestützte Umsetzung von <see cref="IRegisterHistorie"/> (§6.2).
///
/// Der Stand wird gerechnet und nicht mitgeschrieben: Lücken und Befunde
/// hängen am Bestand, und ein mitgeführter Zähler wäre nach der ersten von Hand
/// berichtigten Zeile falsch — und zwar wortlos.
/// </summary>
public sealed class RegisterHistorie(AutomationDbContext db, ISachgebietKatalog katalog) : IRegisterHistorie
{
    public async Task<IReadOnlyList<RegisterHistorieEntity>> GetAllAsync(
        int? jahr,
        CancellationToken cancellationToken = default)
        => await db.RegisterHistorie
            .AsNoTracking()
            .Where(zeile => jahr == null || zeile.Jahr == jahr)
            .OrderBy(zeile => zeile.Jahr)
            .ThenBy(zeile => zeile.LaufendeNummer)
            .ToListAsync(cancellationToken);

    public async Task<RegisterHistorieEntity?> GetAsync(
        int id,
        CancellationToken cancellationToken = default)
        => await db.RegisterHistorie
            .AsNoTracking()
            .FirstOrDefaultAsync(zeile => zeile.Id == id, cancellationToken);

    public async Task<RegisterHistorieStand> StandAsync(CancellationToken cancellationToken = default)
    {
        // Zwei Abfragen statt der ganzen Tabelle: Die Kennzahlen rechnet die
        // Datenbank, geladen werden nur die Nummern — und die braucht es, weil
        // sich eine Lücke nicht aggregieren lässt.
        var kennzahlen = await db.RegisterHistorie
            .AsNoTracking()
            .GroupBy(zeile => zeile.Jahr)
            .Select(gruppe => new
            {
                Jahr = gruppe.Key,
                Zeilen = gruppe.Count(),
                Hoechste = gruppe.Max(zeile => zeile.LaufendeNummer),
                MitBefund = gruppe.Count(zeile => zeile.BefundeJson != "[]" && zeile.BefundeJson != ""),
                Zuletzt = gruppe.Max(zeile => zeile.ImportiertAm),
            })
            .ToListAsync(cancellationToken);

        var nummern = await db.RegisterHistorie
            .AsNoTracking()
            .Select(zeile => new { zeile.Jahr, zeile.LaufendeNummer })
            .ToListAsync(cancellationToken);

        var nachJahr = nummern
            .GroupBy(zeile => zeile.Jahr)
            .ToDictionary(gruppe => gruppe.Key, gruppe => gruppe.Select(z => z.LaufendeNummer).ToList());

        var jahrgaenge = kennzahlen
            .OrderBy(gruppe => gruppe.Jahr)
            .Select(gruppe => new JahrgangStand(
                gruppe.Jahr,
                gruppe.Zeilen,
                gruppe.Hoechste,
                JahrgangPruefung.Luecken(nachJahr.GetValueOrDefault(gruppe.Jahr, []), []),
                gruppe.MitBefund,
                gruppe.Zuletzt))
            .ToList();

        return new RegisterHistorieStand(jahrgaenge, FehlendeJahrgaenge(jahrgaenge));
    }

    /// <summary>
    /// Die Löcher zwischen dem kleinsten und dem größten übernommenen Jahrgang.
    ///
    /// Kein festes Startjahr: Wie weit das Register zurückreicht, sagt der
    /// Bestand. Nach unten wie nach oben offen zu zählen wäre sinnlos — ein
    /// Jahrgang außerhalb der übernommenen Spanne fehlt nicht, er ist nur noch
    /// nicht an der Reihe.
    /// </summary>
    static IReadOnlyList<int> FehlendeJahrgaenge(List<JahrgangStand> jahrgaenge)
    {
        if (jahrgaenge.Count == 0) return [];

        var vorhanden = jahrgaenge.Select(jahrgang => jahrgang.Jahrgang).ToHashSet();
        var kleinster = vorhanden.Min();
        var groesster = vorhanden.Max();
        return
        [
            .. Enumerable
                .Range(kleinster, groesster - kleinster + 1)
                .Where(jahr => !vorhanden.Contains(jahr))
        ];
    }

    public async Task<RegisterHistorieEntity?> AendereAsync(
        int id,
        RegisterHistorieAenderung aenderung,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(aenderung);

        var zeile = await db.RegisterHistorie
            .FirstOrDefaultAsync(eintrag => eintrag.Id == id, cancellationToken);
        if (zeile is null) return null;

        // AbteilungRoh bleibt: Sie hält fest, wie es in der Datei stand, und
        // ist damit der Beleg, gegen den sich die Berichtigung lesen lässt.
        zeile.Abteilung = AbteilungKuerzel.Normalisiere(aenderung.Abteilung);
        zeile.Sachart = aenderung.Sachart.Trim();
        zeile.Mandant = aenderung.Mandant.Trim();
        zeile.Gegner = aenderung.Gegner.Trim();
        zeile.Sachbestand = aenderung.Sachbestand.Trim();
        zeile.Unfalldatum = aenderung.Unfalldatum.Trim();
        zeile.Rechtsgebiet = aenderung.Rechtsgebiet.Trim();
        zeile.GeaendertAm = DateTime.UtcNow;

        var nachschlag = new SachgebietNachschlag(await katalog.GetAllAsync(cancellationToken));
        var pruefung = RegisterZeilenPruefung.Pruefe(AlsImportZeile(zeile), nachschlag);
        zeile.BefundeJson = RegisterHistorieListen.Schreib(pruefung.Befunde);

        await db.SaveChangesAsync(cancellationToken);
        return zeile;
    }

    /// <summary>
    /// Die gespeicherte Zeile in der Form, in der sie aus der Datei kam.
    /// Nur dafür da, dass die Nachprüfung dieselbe Klasse benutzt wie der
    /// Import — zwei Fassungen derselben Regel liefen beim ersten Nachbessern
    /// auseinander, und die Zeile trüge dann einen Befund, den niemand
    /// nachrechnen kann.
    /// </summary>
    static ImportRegisterZeile AlsImportZeile(RegisterHistorieEntity zeile) => new(
        zeile.LaufendeNummer,
        zeile.NummerZusatz,
        zeile.Spalte1,
        zeile.Aktenzeichen,
        zeile.Abteilung,
        zeile.AbteilungRoh,
        zeile.Sachart,
        zeile.Mandant,
        zeile.Gegner,
        zeile.Sachbestand,
        zeile.Unfalldatum,
        zeile.Rechtsgebiet,
        zeile.Freitext,
        zeile.Sicherheit,
        RegisterHistorieListen.Lies(zeile.HinweiseJson));
}
