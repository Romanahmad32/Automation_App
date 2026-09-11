using System.Text.Json;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using FluentAssertions.Execution;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft <see cref="KennzeichenVergleich"/> gegen die Falltabelle
/// docs/kennzeichen_faelle.json, die das Frontend ebenso liest
/// (test/core/general_classes/kennzeichen_normalisierung_test.dart). Zwei von
/// Hand gepflegte Tabellen sind genau das, was bis #144 auseinandergelaufen ist:
/// Das Backend fand eine Antwort zu <c>HGE1427</c> nicht beim Vorgang
/// <c>H-GE 1427</c>, das Frontend schon.
/// </summary>
public class KennzeichenVergleichTests
{
    static JsonElement Faelle(string abschnitt)
    {
        var pfad = Path.Combine(RepoWurzel.Pfad(), "docs", "kennzeichen_faelle.json");
        using var dokument = JsonDocument.Parse(File.ReadAllText(pfad));
        return dokument.RootElement.GetProperty(abschnitt).Clone();
    }

    [Fact]
    public void Lesarten_WieInDerFalltabelle()
    {
        using (new AssertionScope())
        {
            foreach (var fall in Faelle("lesarten").EnumerateArray())
            {
                var eingabe = fall.GetProperty("eingabe").GetString();
                var erwartet = fall.GetProperty("lesarten").EnumerateArray()
                    .Select(lesart => lesart.GetString()!)
                    .ToList();

                KennzeichenVergleich.Lesarten(eingabe)
                    .Should().Equal(erwartet, $"so liest die Tabelle \"{eingabe}\"");
            }
        }
    }

    [Fact]
    public void Gleich_WieInDerFalltabelle_InBeidenRichtungen()
    {
        using (new AssertionScope())
        {
            foreach (var fall in Faelle("vergleiche").EnumerateArray())
            {
                var a = fall.GetProperty("a").GetString();
                var b = fall.GetProperty("b").GetString();
                var gleich = fall.GetProperty("gleich").GetBoolean();

                KennzeichenVergleich.Gleich(a, b).Should().Be(gleich, $"\"{a}\" gegen \"{b}\"");
                KennzeichenVergleich.Gleich(b, a).Should().Be(gleich, $"\"{b}\" gegen \"{a}\"");
            }
        }
    }
}
