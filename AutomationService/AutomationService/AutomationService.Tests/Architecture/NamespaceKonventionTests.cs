using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Haelt Namespace und Ordnerstruktur deckungsgleich.
///
/// Klingt nach Kosmetik, ist aber die Voraussetzung dafuer, dass die
/// Slice-Isolationstests ueberhaupt greifen: sie lesen die Zugehoerigkeit einer
/// Datei aus ihrem Pfad und den Verstoss aus den using-Zeilen. Faellt beides
/// auseinander, meldet ein Slice-Test gruen, obwohl die Abhaengigkeit besteht.
/// </summary>
public class NamespaceKonventionTests
{
    [Fact]
    public void Jede_Quelldatei_deklariert_einen_Namespace()
    {
        var ohneNamespace = CsQuelldateien.Alle()
            .Where(datei => !datei.RelativerPfad.EndsWith("/Program.cs", StringComparison.Ordinal))
            .Where(datei => datei.DeklariertTyp)
            .Where(datei => datei.Namespace is null)
            .Select(datei => datei.RelativerPfad)
            .ToList();

        ohneNamespace.Should().BeEmpty(
            "Typen im globalen Namespace entziehen sich jeder Schichtregel und sind " +
            "von ueberall sichtbar. Ausgenommen sind Program.cs als Top-Level-Programm " +
            "und Dateien, die nur Assembly-Attribute enthalten -- die koennen gar " +
            "keinen Namespace haben");
    }

    [Fact]
    public void Namespace_entspricht_dem_Ordnerpfad()
    {
        var abweichungen = new List<string>();

        foreach (var datei in CsQuelldateien.Alle())
        {
            if (datei.Namespace is null)
            {
                continue; // eigener Test oben
            }

            var ordner = datei.RelativerPfad.TrimStart('/');
            var letzterTrenner = ordner.LastIndexOf('/');
            ordner = letzterTrenner < 0 ? string.Empty : ordner[..letzterTrenner];

            var erwartet = string.IsNullOrEmpty(ordner)
                ? "AutomationService"
                : "AutomationService." + ordner.Replace('/', '.');

            // Das Testprojekt liegt im Ordner des Web-Projekts und traegt
            // deshalb den Praefix AutomationService.Tests statt
            // AutomationService.AutomationService.Tests.
            erwartet = erwartet.Replace(
                "AutomationService.AutomationService.Tests",
                "AutomationService.Tests",
                StringComparison.Ordinal);

            if (datei.Namespace != erwartet)
            {
                abweichungen.Add($"{datei.RelativerPfad}: ist '{datei.Namespace}', erwartet '{erwartet}'");
            }
        }

        abweichungen.Should().BeEmpty(
            "Namespace und Ordner muessen deckungsgleich bleiben, sonst laufen die " +
            "Slice-Isolationstests ins Leere: sie lesen den Slice aus dem Pfad und " +
            "die Abhaengigkeit aus dem Namespace");
    }
}
