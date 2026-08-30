using System.Globalization;
using System.Linq.Expressions;
using System.Text.Json;
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

    /// <summary>
    /// Derselbe Filter wie in <see cref="Aus"/>, aber als Ausdruck — damit die
    /// Datenbank die Zeilen <em>zählen</em> kann, statt sie erst alle zu laden
    /// und bauen zu lassen. Genutzt von <c>StandAsync</c>, das beim Öffnen der
    /// Registerseite nur die Anzahl braucht.
    ///
    /// Steht hier und nicht im Dienst, weil „welche Zeile kommt in die Datei"
    /// eine fachliche Regel ist und es sie nur einmal geben darf. Dass beide
    /// Wege dasselbe zählen, hält <c>RegisterSpiegelZeilenzahlTests</c> fest.
    /// </summary>
    public static Expression<Func<VorgangEntity, bool>> Dateifilter(bool nurAbgeschlossene) =>
        nurAbgeschlossene
            ? v => v.Status == VorgangAbschlussService.StatusVersendet
            : _ => true;

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
    ///
    /// <c>IsAsciiDigit</c> und nicht <c>IsDigit</c>: Letzteres nimmt auch
    /// Ziffern anderer Schriften an (etwa ٢٦), aus denen dann ein Jahrgang
    /// „20٢٦" entstünde, den das Frontend nie erzeugt. Die Zusage lautet,
    /// dieselbe Antwort zu geben wie <c>RegisterFilter.jahrgang</c> — und Darts
    /// <c>\d</c> kennt nur 0–9.
    /// </summary>
    public static string Jahrgang(VorgangEntity v)
    {
        var jahr = (v.Jahr ?? string.Empty).Trim();
        if (jahr.Length == 4 && jahr.All(char.IsAsciiDigit)) return jahr;
        if (jahr.Length == 2 && jahr.All(char.IsAsciiDigit)) return $"20{jahr}";

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
        var rechts = Gegenseite(v);
        if (links.Length == 0 && rechts.Length == 0) return string.Empty;
        return $"{links} ./. {rechts}".Trim();
    }

    /// <summary>
    /// Die Gegenseite. Fehlt der eingetragene Gegner, tritt der Versicherer aus
    /// der Zentralruf-Antwort an seine Stelle — genauso wie im Frontend
    /// (<c>Vorgang.parteienBezeichnung</c>). Ohne diesen Rückfall stünde in der
    /// Datei „Mustermann ./." mit hängendem Trenner, während der Bildschirm
    /// daneben den Versicherer zeigt — und das in der Spalte, um die es dem
    /// Register geht.
    /// </summary>
    static string Gegenseite(VorgangEntity v)
    {
        var eingetragen = (v.Gegner ?? string.Empty).Trim();
        return eingetragen.Length > 0 ? eingetragen : (AntwortVersicherer(v) ?? string.Empty).Trim();
    }

    /// <summary>
    /// Der Versicherername aus der Zentralruf-Antwort, falls eine vorliegt.
    ///
    /// <c>AntwortJson</c> ist für das Backend ein <em>opakes</em> Feld:
    /// Geschrieben hat es das Frontend, der Dienst reicht es nur durch (siehe
    /// <c>VorgangDto</c>). Deshalb wird hier eine einzelne Eigenschaft gelesen
    /// statt in einen Typ gewandelt — und ihr Name ohne Rücksicht auf Gross-
    /// und Kleinschreibung gesucht, weil die Schreibweise im Bestand daran
    /// hängt, wer den Satz zuletzt geschrieben hat.
    ///
    /// Ein unlesbares JSON heisst hier: kein Versicherer. Ein Registerauszug,
    /// der wegen eines kaputten Feldes gar nicht entsteht, wäre die schlechtere
    /// Antwort als einer mit einer Lücke in einer Zelle.
    /// </summary>
    static string? AntwortVersicherer(VorgangEntity v)
    {
        if (string.IsNullOrWhiteSpace(v.AntwortJson)) return null;

        try
        {
            using var dokument = JsonDocument.Parse(v.AntwortJson);
            if (dokument.RootElement.ValueKind != JsonValueKind.Object) return null;

            foreach (var eigenschaft in dokument.RootElement.EnumerateObject())
            {
                if (!string.Equals(eigenschaft.Name, "versichererName", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                return eigenschaft.Value.ValueKind == JsonValueKind.String
                    ? eigenschaft.Value.GetString()
                    : null;
            }

            return null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    static string Sachbestand(VorgangEntity v)
    {
        var datum = (v.UnfallDatum ?? string.Empty).Trim();
        return datum.Length == 0 ? string.Empty : $"Sachverhalt v. {datum}";
    }
}
