using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Begrenzt die Laenge handgeschriebener C#-Dateien.
///
/// Die Regel ist dieselbe wie im Frontend: Richtwert 250, hart 300.
///
/// Bei Einfuehrung lagen vier Dateien darueber; sie standen in einer
/// Altlastenliste mit ihrer damaligen Laenge als Obergrenze, damit sie nur
/// noch schrumpfen konnten. Alle vier sind inzwischen aufgeteilt, die Liste
/// ist weggefallen -- die Regel gilt ausnahmslos. Kommt je wieder eine
/// begruendete Ausnahme dazu, gehoert sie namentlich hierher und nicht als
/// hochgesetztes Limit.
/// </summary>
public class DateilaengeTests
{
    const int Richtwert = 250;
    const int HartesLimit = 300;

    [Fact]
    public void Keine_Datei_ueberschreitet_das_harte_Limit()
    {
        var verstoesse = CsQuelldateien.Alle()
            .Where(datei => datei.Zeilenzahl > HartesLimit)
            .Select(datei => $"{datei.RelativerPfad} ({datei.Zeilenzahl} Zeilen)")
            .ToList();

        verstoesse.Should().BeEmpty(
            $"Dateien sollen hoechstens {Richtwert} Zeilen haben, im Ausnahmefall {HartesLimit}. " +
            $"Was darueber liegt, gehoert in eigenstaendige Klassen aufgeteilt");
    }
}
