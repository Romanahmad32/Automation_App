namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Berechnet RVG-Anwaltskosten nach § 13 Abs. 1 RVG (Wertgebühren, Stand KostBRÄG 2025)
/// und Nr. 7002 VV RVG (Auslagenpauschale).
/// </summary>
public static class RvgFeeCalculator
{
    private const decimal BaseFee = 51.50m;
    private const decimal BaseLimit = 500m;
    private const decimal ExpenseFlatRateCap = 20.00m;
    private const decimal VatRate = 0.19m;

    // (Obergrenze, Schrittweite, Erhöhung je angefangenem Schritt) gemäß § 13 Abs. 1 Satz 2 RVG.
    // Referenz ist die amtliche Gebührentabelle (Anlage 2 zu § 13 RVG); die Tests pinnen
    // WertgebuehrFor auf deren veröffentlichte Tabellenwerte.
    private static readonly (decimal Limit, decimal Step, decimal Increment)[] Brackets =
    [
        (2_000m, 500m, 41.50m),
        (10_000m, 1_000m, 59.50m),
        (25_000m, 3_000m, 55.00m),
        (50_000m, 5_000m, 86.00m),
        (200_000m, 15_000m, 99.50m),
        (500_000m, 30_000m, 140.00m),
        (decimal.MaxValue, 50_000m, 175.00m)
    ];

    /// <param name="gegenstandswert">
    /// Gegenstandswert in € — Grundlage der Wertgebühr nach § 13 RVG.
    /// </param>
    /// <param name="gebuehrensatz">
    /// Gebührensatz der Geschäftsgebühr (Regelsatz 1,3 nach Nr. 2300 VV RVG).
    /// </param>
    /// <param name="applyVat">
    /// Ob Umsatzsteuer nach Nr. 7008 VV RVG aufzuschlagen ist (entfällt bei
    /// vorsteuerabzugsberechtigten Mandanten).
    /// </param>
    /// <param name="geschaeftsgebuehrOverride">
    /// Manuell korrigierte Geschäftsgebühr in €. Ersetzt den berechneten Wert
    /// (Wertgebühr × Gebührensatz); Auslagenpauschale und USt rechnen darauf auf.
    /// </param>
    /// <param name="auslagenpauschaleOverride">
    /// Manuell korrigierte Auslagenpauschale in € (z. B. tatsächliche Auslagen statt
    /// der Pauschale nach Nr. 7002 VV RVG — darf deshalb auch über 20 € liegen).
    /// </param>
    public static RvgCalculation Calculate(
        decimal gegenstandswert,
        decimal gebuehrensatz = 1.3m,
        bool applyVat = false,
        decimal? geschaeftsgebuehrOverride = null,
        decimal? auslagenpauschaleOverride = null)
    {
        if (gegenstandswert <= 0)
            throw new ArgumentOutOfRangeException(nameof(gegenstandswert), "Gegenstandswert muss positiv sein.");
        if (gebuehrensatz <= 0)
            throw new ArgumentOutOfRangeException(nameof(gebuehrensatz), "Gebührensatz muss positiv sein.");
        if (geschaeftsgebuehrOverride is < 0)
            throw new ArgumentOutOfRangeException(nameof(geschaeftsgebuehrOverride), "Korrigierte Geschäftsgebühr darf nicht negativ sein.");
        if (auslagenpauschaleOverride is < 0)
            throw new ArgumentOutOfRangeException(nameof(auslagenpauschaleOverride), "Korrigierte Auslagenpauschale darf nicht negativ sein.");

        var wertgebuehr = WertgebuehrFor(gegenstandswert);
        var geschaeftsgebuehr = geschaeftsgebuehrOverride
            ?? Math.Round(wertgebuehr * gebuehrensatz, 2, MidpointRounding.AwayFromZero);
        var auslagenpauschale = auslagenpauschaleOverride
            ?? Math.Min(Math.Round(geschaeftsgebuehr * 0.2m, 2, MidpointRounding.AwayFromZero), ExpenseFlatRateCap);
        var netto = geschaeftsgebuehr + auslagenpauschale;
        var umsatzsteuer = applyVat ? Math.Round(netto * VatRate, 2, MidpointRounding.AwayFromZero) : 0m;

        return new RvgCalculation(
            gegenstandswert,
            gebuehrensatz,
            wertgebuehr,
            geschaeftsgebuehr,
            auslagenpauschale,
            netto,
            umsatzsteuer,
            netto + umsatzsteuer);
    }

    public static decimal WertgebuehrFor(decimal gegenstandswert)
    {
        var fee = BaseFee;
        var coveredValue = BaseLimit;

        foreach (var (limit, step, increment) in Brackets)
        {
            if (gegenstandswert <= coveredValue)
                break;

            var valueInBracket = Math.Min(gegenstandswert, limit) - coveredValue;
            var steps = Math.Ceiling(valueInBracket / step);
            fee += steps * increment;
            coveredValue = limit;
        }

        return fee;
    }
}

public sealed record RvgCalculation(
    decimal Gegenstandswert,
    decimal Gebuehrensatz,
    decimal Wertgebuehr,
    decimal Geschaeftsgebuehr,
    decimal Auslagenpauschale,
    decimal Netto,
    decimal Umsatzsteuer,
    decimal Brutto);
