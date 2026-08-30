using System.Globalization;
using AutomationService.Features.Vorgaenge.Domain.Persistence;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Macht aus den gespeicherten Vorgängen die Zeilen des Registers: filtern,
/// Jahrgang bestimmen, sortieren.
///
/// Bewusst reine Funktionen ohne Datenbank und ohne Word — das ist die Stelle,
/// an der die fachlichen Regeln stehen (welche Zeile, unter welchem Jahr, in
/// welcher Reihenfolge), und die soll ohne Dateisystem prüfbar sein.
/// </summary>
public static class RegisterZeilenBau
{
    /// <summary>
    /// Baut die Registerzeilen. <paramref name="nurAbgeschlossene"/> entspricht
    /// der Einstellung „Filter der Datei" — der Ansichtsfilter des Frontends
    /// wirkt hier nicht, sonst hinge der Inhalt der Spiegeldatei davon ab, was
    /// gerade am Bildschirm eingestellt war.
    /// </summary>
    public static IReadOnlyList<RegisterZeile> Aus(
        IEnumerable<VorgangEntity> vorgaenge,
        bool nurAbgeschlossene)
    {
        ArgumentNullException.ThrowIfNull(vorgaenge);

        var zeilen = vorgaenge
            .Where(v => !nurAbgeschlossene || IstAbgeschlossen(v))
            .Select(Zeile)
            .ToList();

        // Chronologisch wie die gewachsene Datei: Jahrgang aufsteigend, darin
        // nach laufender Nummer. Zeilen ohne Nummer (noch nicht abgeschlossen)
        // hängen hinten am Jahrgang, weil ihre Nummer erst beim Abschluss
        // vergeben wird und sie sonst jedes Mal die Reihenfolge umwürfen.
        zeilen.Sort((a, b) =>
        {
            var jahr = string.CompareOrdinal(a.Jahr, b.Jahr);
            if (jahr != 0) return jahr;
            if (a.LaufendeNummer is null && b.LaufendeNummer is null)
                return string.CompareOrdinal(a.Zeichen, b.Zeichen);
            if (a.LaufendeNummer is null) return 1;
            if (b.LaufendeNummer is null) return -1;
            return a.LaufendeNummer.Value.CompareTo(b.LaufendeNummer.Value);
        });

        return zeilen;
    }

    /// <summary>Muss zum Statuswert des Frontends passen (VorgangStatus.versendet).</summary>
    static bool IstAbgeschlossen(VorgangEntity v) =>
        string.Equals(v.Status, VorgangAbschlussService.StatusVersendet, StringComparison.Ordinal);

    static RegisterZeile Zeile(VorgangEntity v) => new(
        Jahr: Jahrgang(v),
        LaufendeNummer: v.LaufendeNummer,
        Zeichen: Zeichen(v),
        Parteien: Parteien(v),
        Sachbestand: Sachbestand(v),
        Rechtsgebiet: RechtsgebietAnzeige.Fuer(v.Rechtsgebiet),
        Abgeschlossen: IstAbgeschlossen(v));

    /// <summary>
    /// Vierstelliger Jahrgang. <c>Jahr</c> steht am Vorgang zweistellig ("26"),
    /// weil es aus dem Zeichen kommt ("01/26 C03"); die Überschriften der
    /// Kanzleidatei sind vierstellig. Fehlt das Feld, entscheidet das Datum —
    /// in der Vorlagendatei fehlt ab 2025 die Jahresüberschrift ganz, und
    /// genau diese Lücke soll der Export nicht erben.
    /// </summary>
    public static string Jahrgang(VorgangEntity v)
    {
        var jahr = (v.Jahr ?? string.Empty).Trim();
        if (jahr.Length == 4 && jahr.All(char.IsDigit)) return jahr;
        if (jahr.Length == 2 && jahr.All(char.IsDigit)) return $"20{jahr}";

        var datum = v.AbgeschlossenAm ?? v.AngefragtAm;
        return datum.Year.ToString(CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Spalte 2. Wie der Getter <c>Vorgang.aktenzeichen</c> im Frontend: aus
    /// den Bestandteilen zusammengesetzt, sonst die volle Referenz — die trägt
    /// zusätzlich das Kennzeichen und ist als Notnagel lesbar.
    /// </summary>
    static string Zeichen(VorgangEntity v) =>
        v.LaufendeNummer is not null && !string.IsNullOrWhiteSpace(v.Jahr) && !string.IsNullOrWhiteSpace(v.Abteilung)
            ? $"{v.LaufendeNummer}/{v.Jahr} {v.Abteilung}"
            : v.Referenz;

    static string Parteien(VorgangEntity v)
    {
        var links = (v.MandantName ?? string.Empty).Trim();
        var rechts = (v.Gegner ?? string.Empty).Trim();
        if (links.Length == 0 && rechts.Length == 0) return string.Empty;
        return $"{links} ./. {rechts}".Trim();
    }

    static string Sachbestand(VorgangEntity v)
    {
        var datum = (v.UnfallDatum ?? string.Empty).Trim();
        return datum.Length == 0 ? string.Empty : $"Sachverhalt v. {datum}";
    }
}
