using AutomationService.Features.WordAutomation.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

public class RvgFeeCalculatorTests
{
    [Theory]
    [InlineData(300, 51.50)]    // Bis 500 € gilt die Grundgebühr.
    [InlineData(500, 51.50)]
    [InlineData(1000, 93.00)]   // 51,50 + 1 × 41,50
    [InlineData(5000, 354.50)]  // 51,50 + 3 × 41,50 + 3 × 59,50
    public void WertgebuehrFor_FollowsBracketTable(decimal gegenstandswert, decimal expected)
    {
        RvgFeeCalculator.WertgebuehrFor(gegenstandswert).Should().Be(expected);
    }

    /// <summary>
    /// Referenz: amtliche Gebührentabelle, Anlage 2 zu § 13 RVG (Stand KostBRÄG 2025,
    /// in Kraft seit 01.06.2025). Die Erwartungswerte sind die an den Bracket-Grenzen
    /// veröffentlichten Tabellenwerte — weicht die Berechnung davon ab, ist sie falsch.
    /// </summary>
    [Theory]
    [InlineData(2_000, 176.00)]
    [InlineData(10_000, 652.00)]
    [InlineData(25_000, 927.00)]
    [InlineData(50_000, 1_357.00)]
    [InlineData(200_000, 2_352.00)]
    [InlineData(500_000, 3_752.00)]
    public void WertgebuehrFor_MatchesOfficialFeeTable(decimal gegenstandswert, decimal expected)
    {
        RvgFeeCalculator.WertgebuehrFor(gegenstandswert).Should().Be(expected);
    }

    [Fact]
    public void Wertgebuehr_IsMonotonicallyIncreasing()
    {
        var previous = 0m;
        for (var value = 500m; value <= 100_000m; value += 500m)
        {
            var fee = RvgFeeCalculator.WertgebuehrFor(value);
            fee.Should().BeGreaterThanOrEqualTo(previous);
            previous = fee;
        }
    }

    [Fact]
    public void Calculate_AppliesFactorExpenseCapAndVat()
    {
        var result = RvgFeeCalculator.Calculate(gegenstandswert: 1000m, gebuehrensatz: 1.3m, applyVat: true);

        result.Wertgebuehr.Should().Be(93.00m);
        result.Geschaeftsgebuehr.Should().Be(120.90m); // 93,00 × 1,3
        result.Auslagenpauschale.Should().Be(20.00m);   // 20 % gedeckelt auf 20 €
        result.Netto.Should().Be(140.90m);
        result.Umsatzsteuer.Should().Be(26.77m);        // 140,90 × 19 %
        result.Brutto.Should().Be(167.67m);
    }

    [Fact]
    public void Calculate_WithoutVat_LeavesUmsatzsteuerZero()
    {
        var result = RvgFeeCalculator.Calculate(gegenstandswert: 5000m, gebuehrensatz: 1.3m, applyVat: false);

        result.Umsatzsteuer.Should().Be(0m);
        result.Brutto.Should().Be(result.Netto);
    }

    [Fact]
    public void Calculate_CapsExpenseFlatRateAtTwentyEuro()
    {
        var result = RvgFeeCalculator.Calculate(gegenstandswert: 50_000m, gebuehrensatz: 1.3m);

        result.Auslagenpauschale.Should().Be(20.00m);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-100)]
    public void Calculate_WithNonPositiveValue_Throws(decimal gegenstandswert)
    {
        var action = () => RvgFeeCalculator.Calculate(gegenstandswert);
        action.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void Calculate_WithGeschaeftsgebuehrOverride_UsesCorrectedValueForFollowUps()
    {
        var result = RvgFeeCalculator.Calculate(
            gegenstandswert: 1000m, gebuehrensatz: 1.3m, applyVat: true,
            geschaeftsgebuehrOverride: 80.00m);

        result.Wertgebuehr.Should().Be(93.00m);          // Tabellenwert bleibt als Referenz erhalten.
        result.Geschaeftsgebuehr.Should().Be(80.00m);
        result.Auslagenpauschale.Should().Be(16.00m);    // 20 % der korrigierten Gebühr.
        result.Netto.Should().Be(96.00m);
        result.Umsatzsteuer.Should().Be(18.24m);
        result.Brutto.Should().Be(114.24m);
    }

    [Fact]
    public void Calculate_WithAuslagenpauschaleOverride_AllowsExceedingTheCap()
    {
        var result = RvgFeeCalculator.Calculate(
            gegenstandswert: 1000m, auslagenpauschaleOverride: 35.50m);

        result.Auslagenpauschale.Should().Be(35.50m);
        result.Netto.Should().Be(result.Geschaeftsgebuehr + 35.50m);
    }

    [Fact]
    public void Calculate_WithNegativeGeschaeftsgebuehrOverride_Throws()
    {
        var action = () => RvgFeeCalculator.Calculate(1000m, geschaeftsgebuehrOverride: -1m);
        action.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void Calculate_WithNegativeAuslagenpauschaleOverride_Throws()
    {
        var action = () => RvgFeeCalculator.Calculate(1000m, auslagenpauschaleOverride: -1m);
        action.Should().Throw<ArgumentOutOfRangeException>();
    }
}
