using System.Globalization;

namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Die Platzhalter, die die App aus der Schadensaufstellung selbst füllt —
/// Namen an einer Stelle, Werte an einer Stelle.
///
/// Sie sind Vertrag gegenüber den vorhandenen Kanzleivorlagen: Wer
/// <c>{{RvgBrutto}}</c> in seine Vorlage schreibt, bekommt ihn gefüllt. Die
/// sieben ersten Namen dürfen deshalb nicht umbenannt werden; ergänzt wurde am
/// 03.09.2026 <see cref="Gesamtforderung"/> — die Zahl, die im Brief steht und
/// die die App bisher nur anzeigte, ohne sie herauszugeben (#31).
///
/// Das Frontend spiegelt die Liste in <c>AppEigenePlatzhalter</c>
/// (form_template_setup): Was hier steht, wird dort nie als Eingabefeld
/// angeboten — ein Feld, das die App ohnehin überschreibt, wäre eine Falle.
/// Ein neuer Name gehört an beide Stellen; ein Test hält sie zusammen.
/// </summary>
public static class RvgPlatzhalter
{
    public const string Gegenstandswert = "Gegenstandswert";
    public const string Gebuehrensatz = "Gebuehrensatz";
    public const string Geschaeftsgebuehr = "Geschaeftsgebuehr";
    public const string Auslagenpauschale = "Auslagenpauschale";
    public const string RvgNetto = "RvgNetto";
    public const string RvgUmsatzsteuer = "RvgUmsatzsteuer";
    public const string RvgBrutto = "RvgBrutto";
    public const string Gesamtforderung = "Gesamtforderung";

    /// <summary>Alle acht Namen, ohne die geschweiften Klammern.</summary>
    public static IReadOnlyList<string> Namen { get; } =
    [
        Gegenstandswert,
        Gebuehrensatz,
        Geschaeftsgebuehr,
        Auslagenpauschale,
        RvgNetto,
        RvgUmsatzsteuer,
        RvgBrutto,
        Gesamtforderung
    ];

    private static readonly CultureInfo Kultur = CultureInfo.GetCultureInfo("de-DE");

    /// <summary>
    /// Rechnet die RVG-Kosten zur Aufstellung und legt die acht Werte in die
    /// Ersetzungstabelle. Gibt die Kalkulation zurück, damit der Aufrufer sie
    /// für die Tabelle weiterverwendet, statt ein zweites Mal zu rechnen.
    ///
    /// Hängt bewusst **nicht** an der Tabelle: Ob die Vorlage
    /// <c>{{Schadensaufstellung}}</c> einsetzt, entscheidet über die Tabelle,
    /// nicht über die Kosten. Bis #31 stand diese Zuweisung mitten in
    /// <see cref="DamageListingTable.Insert"/> — die Werte waren damit ein
    /// Nebenprodukt des Tabellenbaus.
    /// </summary>
    public static RvgCalculation Setze(DamageListing listing, Dictionary<string, string> replacementValues)
    {
        ArgumentNullException.ThrowIfNull(listing);
        ArgumentNullException.ThrowIfNull(replacementValues);

        var calculation = RvgFeeCalculator.Calculate(
            listing.Items.Sum(item => item.Amount),
            listing.Gebuehrensatz,
            listing.ApplyVat,
            listing.GeschaeftsgebuehrOverride,
            listing.AuslagenpauschaleOverride);

        replacementValues[Gegenstandswert] = Betrag(calculation.Gegenstandswert);
        replacementValues[Gebuehrensatz] = calculation.Gebuehrensatz.ToString("0.0#", Kultur);
        replacementValues[Geschaeftsgebuehr] = Betrag(calculation.Geschaeftsgebuehr);
        replacementValues[Auslagenpauschale] = Betrag(calculation.Auslagenpauschale);
        replacementValues[RvgNetto] = Betrag(calculation.Netto);
        replacementValues[RvgUmsatzsteuer] = Betrag(calculation.Umsatzsteuer);
        replacementValues[RvgBrutto] = Betrag(calculation.Brutto);
        // Die Zahl, die der Gegner überweisen soll: Schadenssumme plus die
        // Anwaltskosten brutto — dieselbe Rechnung wie die Zeile
        // "Gesamtforderung (inkl. RA-Kosten)" in der App.
        replacementValues[Gesamtforderung] = Betrag(calculation.Gegenstandswert + calculation.Brutto);

        return calculation;
    }

    /// <summary>
    /// Setzt die acht Platzhalter auf leer, wenn keine Schadensaufstellung
    /// erfasst ist.
    ///
    /// Ohne das bleiben sie als <c>{{RvgBrutto}}</c> im fertigen Dokument
    /// stehen — in einem Anspruchsschreiben, das so hinausgeht, ist das ein
    /// Kanzleifehler vor dem Mandanten (#31). Gemeldet wurde der Fall bisher
    /// nur von der Warnliste im Begutachten-Schritt, und eine Warnung, die bei
    /// jedem Schreiben ohne Auflistung erscheint, wird überlesen.
    ///
    /// Ein vom Anwalt selbst erfasstes Feld gleichen Namens bleibt stehen
    /// (<see cref="Dictionary{TKey,TValue}.TryAdd"/>): Leeren soll die Lücke
    /// schließen, nicht eine Eingabe wegwerfen.
    /// </summary>
    public static void Leere(Dictionary<string, string> replacementValues)
    {
        ArgumentNullException.ThrowIfNull(replacementValues);

        foreach (var name in Namen)
            replacementValues.TryAdd(name, string.Empty);
    }

    private static string Betrag(decimal wert) => wert.ToString("N2", Kultur);
}
