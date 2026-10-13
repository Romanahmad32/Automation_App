using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Die Reihenfolge in <c>Program.cs</c>, an der der E2E-Testmodus (#168)
/// hängt — und die nirgends sonst auffiele, bis ein Testlauf auf dem echten
/// Bestand der Kanzlei arbeitet:
/// <list type="bullet">
/// <item>Der Datenordner steht vor <c>AddPersistenceServices</c>: Die
/// Registrierung baut den Verbindungsstring sofort.</item>
/// <item><c>AddDevSimulationServices</c> ist die letzte
/// <c>Add…Services</c>-Registrierung: Ersetzen lässt sich nur, was schon
/// da ist; ein später registrierter echter Dienst stünde wieder daneben.</item>
/// </list>
/// Geprüft wird der Text, nicht der laufende Host: Eine vertauschte Zeile
/// lässt den Host völlig normal starten.
/// </summary>
public sealed class ProgramReihenfolgeTests
{
    private const string DatenordnerZuweisung = "AppDataPaths.Datenordner =";
    private const string Persistenz = "AddPersistenceServices";
    private const string Simulation = "AddDevSimulationServices";

    public static string ProgramText() =>
        string.Join('\n', File.ReadAllLines(Path.Combine(CsQuelldateien.ProjektWurzel(), "Program.cs"))
            .Where(Quelldatei.IstAnweisungszeile));

    [Fact]
    public void Der_Datenordner_steht_vor_der_Persistenz()
    {
        Verstoesse(ProgramText()).Should().BeEmpty();
    }

    [Fact]
    public void Program_cs_enthaelt_beide_Anker()
    {
        var text = ProgramText();

        text.Should().Contain(DatenordnerZuweisung);
        text.Should().Contain(Persistenz);
        text.Should().Contain(Simulation);
    }

    /// <summary>
    /// Negativprobe: dieselbe Prüfung gegen Kopien des Textes mit vertauschter
    /// Reihenfolge schlägt an. Ohne sie bewiese ein grüner Lauf nur, dass die
    /// Prüfung nie etwas findet.
    /// </summary>
    [Fact]
    public void Eine_vertauschte_Reihenfolge_wird_erkannt()
    {
        var text = ProgramText();
        var zeilen = text.Split('\n').ToList();

        var datenordnerNachPersistenz = Tausche(zeilen, DatenordnerZuweisung, Persistenz);
        var simulationNichtLetzte = Tausche(zeilen, Simulation, "AddBackupServices");

        Verstoesse(datenordnerNachPersistenz).Should().ContainSingle().Which.Should().Contain("Datenordner");
        Verstoesse(simulationNichtLetzte).Should().ContainSingle().Which.Should().Contain("letzte");
    }

    private static string Tausche(List<string> zeilen, string a, string b)
    {
        var kopie = zeilen.ToList();
        var ia = kopie.FindIndex(z => z.Contains(a, StringComparison.Ordinal));
        var ib = kopie.FindIndex(z => z.Contains(b, StringComparison.Ordinal));
        (kopie[ia], kopie[ib]) = (kopie[ib], kopie[ia]);
        return string.Join('\n', kopie);
    }

    private static List<string> Verstoesse(string text)
    {
        var zeilen = text.Split('\n');
        var verstoesse = new List<string>();

        var datenordner = Array.FindIndex(zeilen, z => z.Contains(DatenordnerZuweisung, StringComparison.Ordinal));
        var persistenz = Array.FindIndex(zeilen, z => z.Contains(Persistenz, StringComparison.Ordinal));
        if (datenordner < 0 || persistenz < 0 || datenordner > persistenz)
        {
            verstoesse.Add($"Der Datenordner muss vor {Persistenz} gesetzt werden (Zeilen {datenordner}/{persistenz}).");
        }

        var registrierungen = zeilen
            .Where(z => z.Contains(".Add", StringComparison.Ordinal) && z.Contains("Services(", StringComparison.Ordinal))
            .ToList();
        if (registrierungen.Count == 0 || !registrierungen[^1].Contains(Simulation, StringComparison.Ordinal))
        {
            verstoesse.Add($"{Simulation} muss die letzte Add…Services-Registrierung sein.");
        }

        return verstoesse;
    }
}
