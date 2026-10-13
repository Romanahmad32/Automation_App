using AutomationService.Core.Persistence;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Datenordner des E2E-Testmodus (#168) — die eine Einstellung, die
/// entscheidet, ob ein Testlauf auf dem Bestand der Kanzlei arbeitet.
///
/// Geprüft wird die reine Funktion <see cref="AppDataPaths.DatenordnerAus"/>,
/// nicht das Static: Das teilen sich alle parallel laufenden Tests, und im
/// Testlauf hat ohnehin <see cref="AppDataPaths.WurzelFuerTests"/> Vorrang.
/// </summary>
public sealed class AppDataPathsDatenordnerTests
{
    private static IConfiguration Konfiguration(string? datenordner) =>
        new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                [AppDataPaths.DatenordnerSchluessel] = datenordner,
            })
            .Build();

    private static FakeHostEnvironment Umgebung(string name) =>
        new(Path.GetTempPath()) { EnvironmentName = name };

    private static string VollerPfad() => Path.Combine(Path.GetTempPath(), "automation-e2e", "lauf", "daten");

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Ohne_Wert_gilt_der_echte_Ordner(string? wert)
    {
        AppDataPaths.DatenordnerAus(Konfiguration(wert), Umgebung("E2E")).Should().BeNull();
    }

    /// <summary>Die installierte App startet wie immer — nur ein gesetzter Ordner hält sie auf.</summary>
    [Fact]
    public void Ohne_Wert_startet_auch_Production()
    {
        AppDataPaths.DatenordnerAus(Konfiguration(null), Umgebung(Environments.Production)).Should().BeNull();
    }

    [Fact]
    public void In_Production_bricht_ein_gesetzter_Datenordner_den_Start_ab()
    {
        var lesen = () => AppDataPaths.DatenordnerAus(Konfiguration(VollerPfad()), Umgebung(Environments.Production));

        lesen.Should().Throw<InvalidOperationException>().WithMessage("*Production*");
    }

    [Theory]
    [InlineData("daten")]
    [InlineData(@"..\daten")]
    [InlineData(@"\daten")]
    [InlineData("C:daten")]
    public void Ein_unvollstaendiger_Pfad_bricht_den_Start_ab(string wert)
    {
        var lesen = () => AppDataPaths.DatenordnerAus(Konfiguration(wert), Umgebung("E2E"));

        lesen.Should().Throw<InvalidOperationException>().WithMessage("*vollständiger Pfad*");
    }

    [Theory]
    [InlineData("E2E")]
    [InlineData("Development")]
    public void Ausserhalb_von_Production_gilt_der_volle_Pfad(string umgebung)
    {
        var umwegig = Path.Combine(Path.GetTempPath(), "automation-e2e", "lauf", "..", "lauf", "daten");

        AppDataPaths.DatenordnerAus(Konfiguration($"  {umwegig}  "), Umgebung(umgebung))
            .Should().Be(VollerPfad());
    }

    /// <summary>
    /// So übergibt <c>scripts/e2e-start.ps1</c> den Ordner — der Schlüssel ist
    /// Vertrag mit dem Skript und dem Launcher der App.
    /// </summary>
    [Fact]
    public void Die_Kommandozeile_erreicht_den_Datenordner()
    {
        var konfiguration = new ConfigurationBuilder()
            .AddCommandLine(["--Datenordner", VollerPfad()])
            .Build();

        AppDataPaths.DatenordnerAus(konfiguration, Umgebung("E2E")).Should().Be(VollerPfad());
    }

    [Fact]
    public void Im_Testlauf_ist_der_Ordner_umgelenkt()
    {
        AppDataPaths.IstUmgelenkt.Should().BeTrue("TestAppDataUmgebung lenkt jeden Testlauf in ein Temp-Verzeichnis");
        AppDataPaths.EnsureAppDataDirectory().Should().Be(AppDataPaths.WurzelFuerTests);
    }
}
