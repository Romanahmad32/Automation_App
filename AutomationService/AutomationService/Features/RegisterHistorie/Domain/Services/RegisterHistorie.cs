using System.Globalization;
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

    public async Task<bool> LoescheAsync(int id, CancellationToken cancellationToken = default)
    {
        var zeile = await db.RegisterHistorie
            .FirstOrDefaultAsync(eintrag => eintrag.Id == id, cancellationToken);
        if (zeile is null) return false;

        db.RegisterHistorie.Remove(zeile);
        await db.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<RegisterHistorieEntity?> UebernehmeAsync(
        RegisterHistorieUebernahme uebernahme,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(uebernahme);

        var nummerZusatz = uebernahme.NummerZusatz.Trim();

        // Erst prüfen, dann schreiben: Ein DbUpdateException mitten im Löschen
        // des Vorgangs wäre der schlechteste Ausgang. Derselbe natürliche
        // Schlüssel wie am Unique-Index (RegisterHistorieEntityConfiguration) —
        // hier wird die Kollision vor dem Schreiben erkannt statt danach
        // aufgefangen.
        var schonBelegt = await db.RegisterHistorie
            .AsNoTracking()
            .AnyAsync(
                zeile => zeile.Jahr == uebernahme.Jahr
                    && zeile.LaufendeNummer == uebernahme.LaufendeNummer
                    && zeile.NummerZusatz == nummerZusatz,
                cancellationToken);
        if (schonBelegt) return null;

        var abteilung = AbteilungKuerzel.Normalisiere(uebernahme.Abteilung);
        var zeileNeu = new RegisterHistorieEntity
        {
            Kennung = Guid.NewGuid().ToString(),
            Jahr = uebernahme.Jahr,
            LaufendeNummer = uebernahme.LaufendeNummer,
            NummerZusatz = nummerZusatz,
            Spalte1 = uebernahme.Spalte1.Trim(),
            Aktenzeichen = Aktenzeichen(uebernahme.Jahr, uebernahme.LaufendeNummer, nummerZusatz),
            Abteilung = abteilung,
            // Kein Rohwert, weil niemand ihn getippt hat — der Vorgang führte
            // die Abteilung von Anfang an normalisiert.
            AbteilungRoh = abteilung,
            Sachart = string.Empty,
            // Die fertige Parteienspalte landet unverändert in Mandant; Gegner
            // bleibt leer. RegisterHistorieAnzeige.Parteien gibt dann genau
            // diesen Text zurück (Gegenseite und Sachart sind leer) — dieselbe
            // Anzeige wie am Vorgang, ohne die Zerlegung ein zweites Mal
            // nachzubauen.
            Mandant = uebernahme.Parteien.Trim(),
            Gegner = string.Empty,
            // Ebenso beim Sachbestand: die fertige, schon mit dem Datum
            // zusammengesetzte Spalte, Unfalldatum bleibt leer.
            Sachbestand = uebernahme.Sachbestand.Trim(),
            Unfalldatum = string.Empty,
            Rechtsgebiet = uebernahme.Rechtsgebiet.Trim(),
            Freitext = string.Empty,
            // Kein Erzeuger hat hier etwas geschätzt — die Felder kamen aus
            // eigenen Spalten des Vorgangs, nie aus einer Freitextzelle.
            Sicherheit = RegisterSicherheiten.Hoch,
            HinweiseJson = "[]",
            MandantId = null,
            Quelle = RegisterHistorieEntity.QuelleVorgang,
            ImportiertAm = DateTime.UtcNow,
        };

        // Dieselbe Prüfung wie beim Import und wie in AendereAsync: Die Zeile
        // soll sich verhalten wie eine berichtigte, nicht wie eine unbesehen
        // eingefügte.
        var nachschlag = new SachgebietNachschlag(await katalog.GetAllAsync(cancellationToken));
        var pruefung = RegisterZeilenPruefung.Pruefe(AlsImportZeile(zeileNeu), nachschlag);
        zeileNeu.BefundeJson = RegisterHistorieListen.Schreib(pruefung.Befunde);

        db.RegisterHistorie.Add(zeileNeu);
        await db.SaveChangesAsync(cancellationToken);
        return zeileNeu;
    }

    /// <summary>
    /// Das Aktenzeichen im Format der gewachsenen Datei ("10/19-I"), aus den
    /// Bestandteilen des natürlichen Schlüssels — ein Vorgang der App führt
    /// kein eigenes Aktenzeichen in diesem Schema.
    /// </summary>
    static string Aktenzeichen(int jahr, int laufendeNummer, string nummerZusatz)
    {
        var zweistelligesJahr = (((jahr % 100) + 100) % 100).ToString("00", CultureInfo.InvariantCulture);
        return $"{laufendeNummer}/{zweistelligesJahr}{nummerZusatz}";
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
