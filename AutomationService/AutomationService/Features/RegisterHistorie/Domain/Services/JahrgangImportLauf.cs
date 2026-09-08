using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Services;

namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Der Zustand eines einzelnen Jahrgangs während des Imports: die Nummern, die
/// es schon gibt, die Nummern, die diese Datei bringt, und was dabei
/// herauskommt.
///
/// Ein Jahrgang ist die natürliche Einheit der Übernahme — die laufende Nummer
/// läuft je Jahr von 01 aufwärts, also ist „vollständig" nur innerhalb eines
/// Jahrgangs eine Aussage. Deshalb bekommt jeder Jahrgang seinen eigenen Lauf
/// statt eines gemeinsamen Zählwerks über die ganze Datei.
///
/// Wiedererkannt wird über <c>(LaufendeNummer, NummerZusatz)</c> innerhalb des
/// Jahrgangs — der Zusatz gehört dazu, weil <c>10/19</c> und <c>10/19-I</c>
/// zwei Akten sind. Was es schon gibt, bleibt unangetastet: Die Datei
/// überschreibt nie, sonst machte ein zweites Einlesen die Nacharbeit des
/// Anwalts (zugeordneter Mandant, berichtigte Felder) wieder zunichte.
///
/// Eine Zeile ohne laufende Nummer hat keinen natürlichen Schlüssel — mehrere
/// davon dürfen im selben Jahrgang nebeneinander stehen (siehe
/// <c>RegisterHistorieEntityConfiguration</c>, der Unique-Index gilt nur für
/// <c>LaufendeNummer &gt; 0</c>). Wiedererkannt wird sie deshalb ersatzweise
/// über <c>(NummerZusatz, Freitext)</c>: Kommt derselbe Freitext im Bestand
/// schon so oft vor, gilt sie als unverändert, jede zusätzliche als neu. Bei
/// mehrdeutigem Freitext (z. B. zwei wortgleiche Zeilen, von denen nur eine
/// schon im Bestand ist) ist das kein exakter Abgleich, verhindert aber den
/// häufigen Fall — ein Jahrgang wird versehentlich zweimal eingelesen —, dass
/// dieselbe Zeile ein zweites Mal angelegt wird.
/// </summary>
public sealed class JahrgangImportLauf(
    ImportJahrgang jahrgang,
    IReadOnlyCollection<(int Nummer, string Zusatz, string Freitext)> bestand,
    SachgebietNachschlag katalog,
    DateTime jetzt)
{
    readonly HashSet<(int, string)> _bestand =
        [.. bestand
            .Where(eintrag => eintrag.Nummer > 0)
            .Select(eintrag => JahrgangPruefung.Schluessel(eintrag.Nummer, eintrag.Zusatz))];

    // Zählt je (Zusatz, Freitext), wie viele nummernlose Zeilen der Bestand
    // schon hat — "verbraucht" wird ein Treffer beim Wiedererkennen, damit
    // zwei wortgleiche Bestandszeilen auch zwei Treffer aus der Datei binden
    // und nicht denselben zweimal.
    readonly Dictionary<(string Zusatz, string Freitext), int> _bestandOhneNummer = bestand
        .Where(eintrag => eintrag.Nummer <= 0)
        .GroupBy(eintrag => (eintrag.Zusatz.Trim(), eintrag.Freitext.Trim()))
        .ToDictionary(gruppe => gruppe.Key, gruppe => gruppe.Count());

    readonly HashSet<(int, string)> _ausDerDatei = [];

    // Für die Lückenprüfung zählt nur die Nummer: „10/19-I" füllt dieselbe
    // Stelle der Folge wie „10/19" und darf sie nicht zweimal belegen.
    readonly HashSet<int> _dateiNummern = [];
    readonly List<RegisterZeilenBefund> _eintraege = [];
    readonly List<RegisterHistorieEntity> _neue = [];
    int _abweichungen;

    /// <summary>Die anzulegenden Zeilen — im Prüflauf bleiben sie liegen.</summary>
    public IReadOnlyList<RegisterHistorieEntity> NeueZeilen => _neue;

    /// <summary>
    /// Verarbeitet eine Zeile. <paramref name="zeileImJahrgang"/> ist ihre
    /// 1-basierte Position <em>innerhalb dieses Jahrgangs</em> — der Bezug
    /// zurück in die Befundkarte, die der Anwalt vor sich hat. Er prüft und
    /// gibt jahrgangsweise frei, und die Oberfläche spricht eine Zeile deshalb
    /// als (Jahrgang, Zeile) an.
    /// </summary>
    public void Verarbeite(int zeileImJahrgang, ImportRegisterZeile quelle)
    {
        ArgumentNullException.ThrowIfNull(quelle);

        var pruefung = RegisterZeilenPruefung.Pruefe(quelle, katalog);
        var befunde = new List<string>(pruefung.Befunde);
        if (pruefung.Abweichung) _abweichungen++;

        var art = Einordnen(quelle, befunde);
        if (art == RegisterImportArten.Neu) _neue.Add(Anlegen(quelle, befunde));

        _eintraege.Add(new RegisterZeilenBefund(
            zeileImJahrgang,
            jahrgang.Jahrgang,
            quelle.LaufendeNummer,
            quelle.Aktenzeichen.Trim(),
            RegisterHistorieAnzeige.Parteien(quelle.Mandant, quelle.Gegner, quelle.Sachart),
            quelle.Rechtsgebiet.Trim(),
            RegisterSicherheiten.Normalisiere(quelle.Sicherheit),
            art,
            befunde,
            quelle.Hinweise));
    }

    /// <summary>Der Befund über diesen Jahrgang, wenn alle Zeilen durch sind.</summary>
    public JahrgangBefund Ergebnis() => new(
        jahrgang.Jahrgang,
        _eintraege.Count,
        JahrgangPruefung.Luecken(_dateiNummern, _bestand.Select(eintrag => eintrag.Item1)),
        JahrgangPruefung.Doppelte(jahrgang.Zeilen
            .Where(zeile => zeile.LaufendeNummer > 0)
            .Select(zeile => (zeile.LaufendeNummer, zeile.NummerZusatz))),
        Neu: Zaehle(RegisterImportArten.Neu),
        Unveraendert: Zaehle(RegisterImportArten.Unveraendert),
        Abgelehnt: Zaehle(RegisterImportArten.Abgelehnt),
        ZuPruefen: _eintraege.Count(eintrag => eintrag.ZuPruefen),
        Abweichungen: _abweichungen,
        Eintraege: _eintraege);

    int Zaehle(string art) => _eintraege.Count(eintrag => eintrag.Art == art);

    /// <summary>
    /// Neu, unverändert oder abgelehnt.
    ///
    /// Abgelehnt wird <b>nur</b> eine echte Doppelnummer — dieselbe Nummer mit
    /// demselben Zusatz ein zweites Mal in derselben Datei. Alles andere wird
    /// übernommen, wie es im Originalregister steht, und trägt seinen Befund:
    /// Ein widersprüchlicher Eintrag ist Teil des Bestands, und eine App, die
    /// ihn abweist, führt ein Register, das es so nie gab.
    ///
    /// Eine Zeile ohne laufende Nummer ist <b>nie</b> eine Dublette: Ohne
    /// Nummer gibt es keinen Schlüssel, über den zwei Zeilen kollidieren
    /// könnten, und die Duplikatprüfung liefe sonst allein über den
    /// Platzhalter (0, Zusatz) — zwei nummernlose Zeilen mit demselben Zusatz
    /// wären dann fälschlich eine „Doppelnummer 0". Sie wird deshalb immer
    /// <see cref="RegisterImportArten.Neu"/>, außer der Bestand hat schon
    /// erkennbar dieselbe Zeile (<see cref="WiedererkanntOhneNummer"/>).
    /// </summary>
    string Einordnen(ImportRegisterZeile quelle, List<string> befunde)
    {
        if (quelle.LaufendeNummer <= 0)
        {
            befunde.Add("Ohne laufende Nummer — die Zeile steht außerhalb der Nummernfolge.");
            return WiedererkanntOhneNummer(quelle) ? RegisterImportArten.Unveraendert : RegisterImportArten.Neu;
        }

        _dateiNummern.Add(quelle.LaufendeNummer);

        var schluessel = JahrgangPruefung.Schluessel(quelle.LaufendeNummer, quelle.NummerZusatz);
        if (!_ausDerDatei.Add(schluessel))
        {
            befunde.Add(
                $"Nummer {quelle.LaufendeNummer}{schluessel.Zusatz} kommt in der Datei doppelt vor — " +
                "zweite Zeile nicht übernommen.");
            return RegisterImportArten.Abgelehnt;
        }

        return _bestand.Contains(schluessel)
            ? RegisterImportArten.Unveraendert
            : RegisterImportArten.Neu;
    }

    /// <summary>
    /// Ob eine nummernlose Zeile schon im Bestand steht — ersatzweise über
    /// <c>(NummerZusatz, Freitext)</c>, weil ihr die laufende Nummer als
    /// Schlüssel fehlt. Ein Treffer wird verbraucht (siehe
    /// <see cref="_bestandOhneNummer"/>): Bringt die Datei denselben Freitext
    /// öfter, als der Bestand ihn hat, gilt die zusätzliche Zeile als neu statt
    /// als Dublette einer bereits erkannten.
    /// </summary>
    bool WiedererkanntOhneNummer(ImportRegisterZeile quelle)
    {
        var schluessel = (quelle.NummerZusatz.Trim(), quelle.Freitext.Trim());
        if (!_bestandOhneNummer.TryGetValue(schluessel, out var uebrig) || uebrig <= 0) return false;

        _bestandOhneNummer[schluessel] = uebrig - 1;
        return true;
    }

    RegisterHistorieEntity Anlegen(ImportRegisterZeile quelle, IEnumerable<string> befunde) => new()
    {
        Kennung = Guid.NewGuid().ToString(),
        Jahr = jahrgang.Jahrgang,
        LaufendeNummer = quelle.LaufendeNummer,
        NummerZusatz = quelle.NummerZusatz.Trim(),
        Spalte1 = quelle.Spalte1.Trim(),
        Aktenzeichen = quelle.Aktenzeichen.Trim(),
        Abteilung = AbteilungKuerzel.Normalisiere(quelle.Abteilung),
        // Fällt auf die normalisierte Schreibweise zurück: Wer die Rohfassung
        // nicht mitliefert, soll nicht dafür sorgen, dass die Spalte leer bleibt.
        AbteilungRoh = quelle.AbteilungRoh.Trim().Length > 0
            ? quelle.AbteilungRoh.Trim()
            : quelle.Abteilung.Trim(),
        Sachart = quelle.Sachart.Trim(),
        Mandant = quelle.Mandant.Trim(),
        Gegner = quelle.Gegner.Trim(),
        Sachbestand = quelle.Sachbestand.Trim(),
        Unfalldatum = quelle.Unfalldatum.Trim(),
        Rechtsgebiet = quelle.Rechtsgebiet.Trim(),
        Freitext = quelle.Freitext.Trim(),
        Sicherheit = RegisterSicherheiten.Normalisiere(quelle.Sicherheit),
        HinweiseJson = RegisterHistorieListen.Schreib(quelle.Hinweise),
        BefundeJson = RegisterHistorieListen.Schreib(befunde),
        MandantId = null,
        Quelle = RegisterHistorieEntity.QuelleImport,
        ImportiertAm = jetzt,
    };
}
