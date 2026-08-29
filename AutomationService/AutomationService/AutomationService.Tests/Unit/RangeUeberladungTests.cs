using System.ComponentModel.DataAnnotations;
using System.Reflection;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Haelt fest, dass jede <c>[Range]</c> an einer <c>decimal</c>-Eigenschaft in
/// <c>double</c> vergleicht und nicht in <c>int</c>.
///
/// Warum ein eigener Test dafuer: <c>[Range(0, 10_000_000)]</c> und
/// <c>[Range(0.0, 10_000_000.0)]</c> sehen im Diff fast gleich aus, verhalten sich aber
/// verschieden. Ganzzahlige Literale binden <c>RangeAttribute(int, int)</c>; der
/// <c>OperandType</c> wird damit <c>Int32</c>, und der uebergebene <c>decimal</c> wird
/// **vor** dem Vergleich gerundet. Zwei Folgen, beide gemessen:
///
/// - <c>-0,49</c> rundet auf 0 und gilt als gueltig — ein negativer Betrag kaeme durch
///   die Validierung, die genau das verhindern soll, und stuende so im Schreiben.
/// - Ein Wert jenseits von <c>int.MaxValue</c> wirft beim Konvertieren eine
///   <c>OverflowException</c>. <c>RangeAttribute</c> faengt nur Format-, InvalidCast- und
///   NotSupported-Fehler ab, die Validierung fliegt also auseinander: aus 400
///   "validation_failed" wird ein 500.
///
/// Der Fehler ist hier schon zweimal entstanden — beim Oeffnen der Untergrenze von 0,01
/// auf 0 (#27) und davor unbemerkt an den vier Override-Feldern. Deshalb sammelt dieser
/// Test die Grenzen **selbst ein**, statt sie aufzuzaehlen: Eine Handliste haette die
/// Nachbarn derselben Datei nicht erwischt, und genau das ist passiert. Jede neue
/// Geldgrenze faellt ab jetzt von allein unter die Regel.
///
/// Nicht betroffen sind <c>[Range]</c> an <c>int</c>-Eigenschaften
/// (<c>ZentralrufPrefillDto</c>): Dort ist die int-Ueberladung die richtige.
/// </summary>
public class RangeUeberladungTests
{
    /// <summary>
    /// Alle <c>decimal</c>-Eigenschaften mit <c>[Range]</c> aus der Presentation-Schicht
    /// des Dienstes — eingesammelt aus der Assembly, nicht von Hand gepflegt.
    /// </summary>
    public static TheoryData<string, RangeAttribute> Geldgrenzen()
    {
        var daten = new TheoryData<string, RangeAttribute>();
        var dtoTypen = typeof(DamageListingDto).Assembly
            .GetTypes()
            .Where(typ => typ.IsClass && typ.Namespace?.Contains(".Presentation.Dtos", StringComparison.Ordinal) == true);

        foreach (var typ in dtoTypen)
        {
            foreach (var eigenschaft in typ.GetProperties(BindingFlags.Public | BindingFlags.Instance))
            {
                var istGeld = Nullable.GetUnderlyingType(eigenschaft.PropertyType) == typeof(decimal)
                    || eigenschaft.PropertyType == typeof(decimal);
                var grenze = eigenschaft.GetCustomAttribute<RangeAttribute>();
                if (istGeld && grenze is not null)
                {
                    daten.Add($"{typ.Name}.{eigenschaft.Name}", grenze);
                }
            }
        }

        return daten;
    }

    /// <summary>
    /// Ohne diese Zusicherung koennte die Sammlung oben still leer laufen — etwa wenn die
    /// DTOs den Namespace wechseln — und der Test meldete Erfolg fuer eine Pruefung, die
    /// nie gelaufen ist.
    /// </summary>
    [Fact]
    public void Geldgrenzen_WerdenUeberhauptGefunden()
    {
        Geldgrenzen().Should().HaveCountGreaterThanOrEqualTo(
            6, "die WordAutomation-DTOs tragen sechs Geldgrenzen; findet der Test weniger, sucht er falsch");
    }

    [Theory]
    [MemberData(nameof(Geldgrenzen))]
    public void Geldgrenze_VergleichtInDouble(string name, RangeAttribute grenze)
    {
        grenze.OperandType.Should().Be<double>(
            "{0} vergliche sonst in Int32 und wuerde den Betrag vorher runden — " +
            "die Grenzen brauchen ihre Nachkommastellen", name);
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
    [InlineData(nameof(DamageItemDto.Amount))]
    public void Betrag_NimmtNullAn(string name)
    {
        var grenze = typeof(DamageItemDto).GetProperty(name)!.GetCustomAttribute<RangeAttribute>()!;

        grenze.IsValid(0m).Should().BeTrue("eine noch unbezifferte Position ist gueltig");
    }
}
