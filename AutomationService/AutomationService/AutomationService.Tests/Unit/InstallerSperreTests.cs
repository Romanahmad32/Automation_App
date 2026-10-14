using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.DependencyInjection;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Das echte Setup startet nur die installierte App (#196). Ein Dienst aus der
/// Entwicklungsumgebung lädt dasselbe Setup von GitHub — gestartet überschriebe
/// es die App, die auf dem Entwicklerrechner installiert ist. Dort lehnt
/// „Jetzt neu starten" mit 409 ab; der E2E-Testmodus hat seine eigene Attrappe.
/// </summary>
public sealed class InstallerSperreTests : IDisposable
{
    private readonly AktualisierungsUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    private static FakeHostEnvironment Umgebung(string name) =>
        new(Path.GetTempPath()) { EnvironmentName = name };

    [Theory]
    [InlineData("Production", null)]
    [InlineData("Development", AktualisierungsMeldungen.NurInstalliert)]
    [InlineData("E2E", AktualisierungsMeldungen.NurInstalliert)]
    [InlineData("Staging", AktualisierungsMeldungen.NurInstalliert)]
    public void Nur_in_Production_darf_der_echte_Installer_starten(string umgebung, string? sperrgrund)
    {
        new InstallerStarter(Umgebung(umgebung), NullLogger<InstallerStarter>.Instance)
            .Sperrgrund.Should().Be(sperrgrund);
    }

    [Fact]
    public void Auch_direkt_aufgerufen_startet_er_ausserhalb_von_Production_nichts()
    {
        var starter = new InstallerStarter(Umgebung(Environments.Development), NullLogger<InstallerStarter>.Instance);
        var aufruf = InstallerAufruf.Fuer(
            Path.Combine(_umgebung.Basis, "gibt-es-nicht.exe"),
            Path.Combine(_umgebung.Basis, "installer.log"),
            _umgebung.Basis,
            Versionsnummer.Lies("1.4.0")!);

        var starten = () => starter.Starte(aufruf);

        // Eine Win32Exception hieße: Er hat es versucht und nur die Datei nicht gefunden.
        starten.Should().Throw<InvalidOperationException>().WithMessage(AktualisierungsMeldungen.NurInstalliert);
    }

    [Fact]
    public async Task Ein_gesperrter_Starter_lehnt_ab_ohne_etwas_zu_veraendern()
    {
        _umgebung.Starter.Sperrgrund = AktualisierungsMeldungen.NurInstalliert;
        using var dienst = _umgebung.Dienst();
        await AktualisierungsUmgebung.LadeBisBereit(dienst);

        var schritt = dienst.Installiere();

        schritt.Ablehnung.Should().Be(AktualisierungsMeldungen.NurInstalliert);
        schritt.Stand.Zustand.Should().Be(AktualisierungsZustand.Bereit, "die Datei ist geladen und geprüft — nur starten geht hier nicht");
        _umgebung.Starter.Aufrufe.Should().BeEmpty();
        File.Exists(_umgebung.Ordner.Merkdatei).Should().BeFalse("ohne Start nichts zu melden");
        _umgebung.Herunterfahren.Anstoesse.Should().Be(0);
    }

    [Fact]
    public void In_der_Entwicklungsumgebung_verdrahtet_ist_der_Installer_gesperrt()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton<IHostEnvironment>(Umgebung(Environments.Development));
        services.AddAktualisierungServices(new ConfigurationBuilder().Build());
        using var anbieter = services.BuildServiceProvider(validateScopes: true);

        anbieter.GetRequiredService<IInstallerStarter>().Sperrgrund.Should().Be(AktualisierungsMeldungen.NurInstalliert);
    }
}
