using System.ComponentModel.DataAnnotations;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Haelt fest, dass die Geldgrenzen der DTOs in <c>double</c> vergleichen und nicht in
/// <c>int</c>.
///
/// Warum ein eigener Test dafuer: <c>[Range(0, 10_000_000)]</c> und
/// <c>[Range(0.0, 10_000_000.0)]</c> sehen im Diff fast gleich aus, verhalten sich aber
/// verschieden. Ganzzahlige Literale binden <c>RangeAttribute(int, int)</c>; der
/// <c>OperandType</c> wird damit <c>Int32</c>, und der uebergebene <c>decimal</c> wird
/// **vor** dem Vergleich gerundet. Zwei Folgen, beide gemessen:
///
/// - <c>-0,49</c> rundet auf 0 und gilt als gueltig — eine negative Position kaeme durch
///   die Validierung, die genau das verhindern soll, und stuende als "-0,49" im Schreiben.
/// - Ein Wert jenseits von <c>int.MaxValue</c> wirft beim Konvertieren eine
///   <c>OverflowException</c>. <c>RangeAttribute</c> faengt nur Format-, InvalidCast- und
///   NotSupported-Fehler ab, die Validierung fliegt also auseinander: aus 400
///   "validation_failed" wird ein 500.
///
/// Der Fehler ist hier schon einmal entstanden, beim Oeffnen der Untergrenze von 0,01 auf
/// 0 (#27) — eine Aenderung, die nach Fachlogik aussah und in Wahrheit die Ueberladung
/// umgeschaltet hat. Kein anderer Test schlaegt dabei an: Der Dienst uebersetzt, alle
/// bisherigen Faelle bleiben gruen, und der Vertrag in docs/openapi.json meldet
/// unveraendert "minimum: 0".
/// </summary>
public class RangeUeberladungTests
{
    private static RangeAttribute RangeVon<T>(string eigenschaft) =>
        (RangeAttribute)Attribute.GetCustomAttribute(
            typeof(T).GetProperty(eigenschaft)!, typeof(RangeAttribute))!;

    public static TheoryData<string, RangeAttribute> Geldgrenzen() => new()
    {
        { "DamageItemDto.Amount", RangeVon<DamageItemDto>(nameof(DamageItemDto.Amount)) },
        {
            "RvgCalculationRequestDto.Gegenstandswert",
            RangeVon<RvgCalculationRequestDto>(nameof(RvgCalculationRequestDto.Gegenstandswert))
        }
    };

    [Theory]
    [MemberData(nameof(Geldgrenzen))]
    public void Geldgrenze_VergleichtInDouble(string name, RangeAttribute grenze)
    {
        grenze.OperandType.Should().Be<double>(
            "{0} vergliche sonst in Int32 und wuerde den Betrag vorher runden", name);
    }

    [Theory]
    [MemberData(nameof(Geldgrenzen))]
    public void Geldgrenze_WeistNachkommaNegativeAb(string name, RangeAttribute grenze)
    {
        grenze.IsValid(-0.49m).Should().BeFalse("{0} darf keinen negativen Betrag annehmen", name);
        grenze.IsValid(-0.5m).Should().BeFalse("{0} darf keinen negativen Betrag annehmen", name);
    }

    [Theory]
    [MemberData(nameof(Geldgrenzen))]
    public void Geldgrenze_LehntZuGrosseWerteAb_StattZuWerfen(string name, RangeAttribute grenze)
    {
        var pruefung = () => grenze.IsValid(3_000_000_000m);

        pruefung.Should().NotThrow("{0} muss 400 liefern koennen, nicht 500", name);
        pruefung().Should().BeFalse();
    }

    /// <summary>Die Oeffnung aus #27: 0,00 bleibt eine gueltige Position.</summary>
    [Theory]
    [MemberData(nameof(Geldgrenzen))]
    public void Geldgrenze_NimmtNullAn(string name, RangeAttribute grenze)
    {
        grenze.IsValid(0m).Should().BeTrue("{0} laesst noch unbezifferte Positionen zu", name);
    }
}
