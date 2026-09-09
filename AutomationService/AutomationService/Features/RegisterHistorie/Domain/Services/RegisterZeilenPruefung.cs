using System.Globalization;
using AutomationService.Features.Sachgebiete.Domain.Services;

namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Was an einer einzelnen Registerzeile auffällt (§6.2).
///
/// Alles hier ist eine <em>Feststellung</em>, keine Berichtigung. Der Bestand
/// hat Tippfehler und Widersprüche; wer sie still glättet, verliert die
/// Information, und wer sie still übernimmt, baut sie ins neue Register ein.
/// Deshalb: übernehmen wie in der Datei und den Widerspruch benennen — die
/// Bereinigung macht der Anwalt in der App, mit Bestätigung.
///
/// Dieselbe Prüfung läuft beim Import und nach jeder Änderung einer
/// gespeicherten Zeile. Zwei Fassungen davon liefen auseinander, und die Zeile
/// trüge dann einen Befund, den niemand mehr nachrechnen kann.
/// </summary>
public static class RegisterZeilenPruefung
{
    /// <summary>Befunde und die Frage, ob Abteilung und Rechtsgebiet auseinandergehen.</summary>
    public sealed record Ergebnis(IReadOnlyList<string> Befunde, bool Abweichung);

    public static Ergebnis Pruefe(ImportRegisterZeile zeile, SachgebietNachschlag katalog)
    {
        ArgumentNullException.ThrowIfNull(zeile);
        ArgumentNullException.ThrowIfNull(katalog);

        var befunde = new List<string>();
        PruefeSpalte1(zeile, befunde);
        var abweichung = PruefeAbteilung(zeile, katalog, befunde);
        PruefeNummernzusatz(zeile, befunde);
        return new Ergebnis(befunde, abweichung);
    }

    /// <summary>
    /// Spalte 1 wiederholt die Nummer aus Spalte 2. Stimmen beide nicht
    /// überein, ist die Freitextzelle falsch zerlegt — die billigste Probe im
    /// ganzen Register, und die einzige, die einen Zerlegefehler findet, ohne
    /// die Akte zu kennen.
    /// </summary>
    static void PruefeSpalte1(ImportRegisterZeile zeile, List<string> befunde)
    {
        var spalte1 = zeile.Spalte1.Trim();
        if (spalte1.Length == 0) return;

        var gelesen = int.TryParse(spalte1, NumberStyles.Integer, CultureInfo.InvariantCulture, out var nummer);
        if (gelesen && nummer == zeile.LaufendeNummer) return;

        befunde.Add(
            $"Spalte 1 „{spalte1}“ widerspricht der Nummer im Aktenzeichen „{zeile.Aktenzeichen}“.");
    }

    /// <summary>
    /// Abteilung gegen Spalte 3, über den Sachgebietskatalog. Gezählt wird
    /// <b>Haupt- und Nebensachgebiet</b>: „C05/3" ist Strafrecht mit
    /// Verkehrsbezug, und „Verkehrsrecht" daneben ist deshalb kein Widerspruch.
    ///
    /// Kein Widerspruch wird gemeldet, wenn eine der beiden Seiten dem Katalog
    /// unbekannt ist. Dann steht das im Befund — behaupten, sie widersprächen
    /// einander, hieße etwas über zwei Werte zu sagen, von denen einer gar
    /// nicht eingeordnet werden konnte.
    /// </summary>
    static bool PruefeAbteilung(ImportRegisterZeile zeile, SachgebietNachschlag katalog, List<string> befunde)
    {
        var abteilung = AbteilungKuerzel.Normalisiere(zeile.Abteilung);
        var rechtsgebiet = zeile.Rechtsgebiet.Trim();

        if (abteilung.Length == 0)
        {
            befunde.Add("Ohne Abteilung.");
            return false;
        }

        var (hauptKuerzel, nebenKuerzel) = AbteilungKuerzel.Zerlege(abteilung);
        var haupt = katalog.Eintrag(hauptKuerzel);
        var neben = katalog.Eintrag(nebenKuerzel);

        if (haupt is null) befunde.Add($"Abteilung „{hauptKuerzel}“ ist im Sachgebietskatalog unbekannt.");
        if (nebenKuerzel is not null && neben is null)
        {
            befunde.Add($"Nebensachgebiet „{nebenKuerzel}“ ist im Sachgebietskatalog unbekannt.");
        }

        if (rechtsgebiet.Length == 0) return false;
        if (!katalog.KenntRechtsgebiet(rechtsgebiet))
        {
            befunde.Add($"Rechtsgebiet „{rechtsgebiet}“ steht nicht im Sachgebietskatalog.");
            return false;
        }

        if (haupt is null) return false;
        if (katalog.Deckt(hauptKuerzel, rechtsgebiet)) return false;
        if (nebenKuerzel is not null && katalog.Deckt(nebenKuerzel, rechtsgebiet)) return false;

        befunde.Add(
            $"Abteilung {hauptKuerzel} ({haupt.Name}) widerspricht Spalte 3 „{rechtsgebiet}“ — " +
            "übernommen wie in der Datei.");
        return true;
    }

    /// <summary>
    /// Ein Zusatz hinter der Nummer („10/19-I") ist kein Fehler, aber er bricht
    /// die Annahme, dass die laufende Nummer eine Zahl ist — und genau daran
    /// hängt die Lückenprüfung. Deshalb kommt er dem Anwalt vor Augen.
    /// </summary>
    static void PruefeNummernzusatz(ImportRegisterZeile zeile, List<string> befunde)
    {
        var zusatz = zeile.NummerZusatz.Trim();
        if (zusatz.Length > 0) befunde.Add($"Nummer trägt den Zusatz „{zusatz}“.");
    }
}
