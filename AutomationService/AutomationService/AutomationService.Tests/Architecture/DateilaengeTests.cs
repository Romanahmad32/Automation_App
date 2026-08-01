using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Begrenzt die Laenge handgeschriebener C#-Dateien.
///
/// Die Regel ist dieselbe wie im Frontend (Richtwert 250, hart 300), hier aber
/// mit einer Besonderheit: der Bestand hat vier Dateien, die darueber liegen.
/// Statt das Limit auf den Ist-Zustand hochzusetzen -- womit die Regel nichts
/// mehr verhindern wuerde -- stehen sie namentlich in <see cref="Altlasten"/>
/// mit ihrer heutigen Laenge als Obergrenze. Damit gilt:
///
/// * eine neue Datei darf das Limit nie ueberschreiten,
/// * eine Altlast darf nicht weiter wachsen, nur schrumpfen,
/// * und wer eine Altlast unter das Limit bringt, nimmt sie aus der Liste.
///
/// So sind die Ausnahmen sichtbar und endlich, statt als stille Duldung im
/// Hintergrund zu verschwinden.
/// </summary>
public class DateilaengeTests
{
    const int Richtwert = 250;
    const int HartesLimit = 300;

    /// <summary>
    /// Dateien aus dem Bestand, die ueber dem harten Limit liegen, mit ihrer
    /// Laenge zum Zeitpunkt der Einfuehrung dieser Regel. Diese Liste soll
    /// kuerzer werden, nie laenger.
    /// </summary>
    static readonly Dictionary<string, int> Altlasten = new(StringComparer.Ordinal)
    {
        ["/Features/WordAutomation/Domain/Services/WordAutomationService.cs"] = 557,
        ["/AutomationService.Tests/Unit/WordAutomationServiceTests.cs"] = 535,
        ["/Features/MailboxMonitor/Presentation/HostedServices/MailboxMonitorService.cs"] = 415,
        ["/Features/ZentralrufAutomation/Domain/Services/ZentralrufAutomationService.cs"] = 403,
    };

    [Fact]
    public void Keine_neue_Datei_ueberschreitet_das_harte_Limit()
    {
        var verstoesse = CsQuelldateien.Alle()
            .Where(datei => !Altlasten.ContainsKey(datei.RelativerPfad))
            .Where(datei => datei.Zeilenzahl > HartesLimit)
            .Select(datei => $"{datei.RelativerPfad} ({datei.Zeilenzahl} Zeilen)")
            .ToList();

        verstoesse.Should().BeEmpty(
            $"Dateien sollen hoechstens {Richtwert} Zeilen haben, im Ausnahmefall {HartesLimit}. " +
            $"Was darueber liegt, gehoert in eigenstaendige Klassen aufgeteilt");
    }

    [Fact]
    public void Altlasten_wachsen_nicht_weiter()
    {
        var gewachsen = new List<string>();

        foreach (var (pfad, obergrenze) in Altlasten)
        {
            var datei = CsQuelldateien.Alle()
                .SingleOrDefault(d => d.RelativerPfad == pfad);

            if (datei is null)
            {
                continue; // eigener Test unten
            }

            if (datei.Zeilenzahl > obergrenze)
            {
                gewachsen.Add($"{pfad}: {datei.Zeilenzahl} Zeilen, erlaubt sind noch {obergrenze}");
            }
        }

        gewachsen.Should().BeEmpty(
            "eine Datei, die bereits ueber dem Limit liegt, darf nicht weiter wachsen. " +
            "Neuer Code in dieser Datei gehoert in eine eigene Klasse");
    }

    [Fact]
    public void Die_Altlastenliste_enthaelt_nichts_Erledigtes()
    {
        var alleDateien = CsQuelldateien.Alle();
        var erledigt = new List<string>();

        foreach (var (pfad, _) in Altlasten)
        {
            var datei = alleDateien.SingleOrDefault(d => d.RelativerPfad == pfad);

            if (datei is null)
            {
                erledigt.Add($"{pfad}: existiert nicht mehr");
            }
            else if (datei.Zeilenzahl <= HartesLimit)
            {
                erledigt.Add($"{pfad}: liegt mit {datei.Zeilenzahl} Zeilen wieder im Limit");
            }
        }

        erledigt.Should().BeEmpty(
            "erledigte Ausnahmen gehoeren aus der Altlastenliste entfernt, sonst " +
            "erlaubt sie stillschweigend wieder Wachstum bis zur alten Obergrenze");
    }
}
