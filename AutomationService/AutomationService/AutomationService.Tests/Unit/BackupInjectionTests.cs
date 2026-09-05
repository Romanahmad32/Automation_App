using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Backup.Presentation.DependencyInjection;
using AutomationService.Features.Backup.Presentation.HostedServices;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Not-Aus der automatischen Sicherung (#39).
///
/// Er ist der Grund, warum ein Testlauf nicht in den OneDrive-Ordner des
/// Anwalts schreibt: Ein <c>WebApplicationFactory</c>-Host faehrt denselben
/// Program.cs gegen dieselbe Datenbank unter %APPDATA%. Ohne den Schalter legte
/// jeder <c>dotnet test</c>-Lauf dort eine echte Sicherung ab — samt
/// Arbeitsplatz-Eintrag, der dem zweiten Rechner einen Stand anbietet, den
/// niemand gearbeitet hat.
///
/// Geprueft wird deshalb am <em>Verhalten</em> und nicht daran, ob ein Hosted
/// Service registriert ist: Es gibt zwei Schreibwege (Beenden und
/// Vorgangsabschluss), und nur einer davon haengt am Hosted Service.
/// </summary>
public sealed class BackupInjectionTests
{
    [Fact]
    public async Task Abgeschaltet_schreibt_die_automatische_Sicherung_nichts()
    {
        var sicherung = Dienst(eingeschaltet: false);

        (await sicherung.SchreibeAsync()).Should().BeNull(
            "abgeschaltet heisst: es gibt nichts zu tun, nicht einmal einen Blick in die Datenbank");
    }

    /// <summary>
    /// Die Uebergabe bleibt auch dann erreichbar: Sie liest nur und spielt
    /// ausschliesslich auf Klick ein. Wer nicht schreiben will, will nicht
    /// blind sein.
    /// </summary>
    [Fact]
    public void Die_Uebergabe_steht_auch_bei_abgeschalteter_Sicherung_bereit()
    {
        Anbieter(eingeschaltet: false)
            .GetRequiredService<IArbeitsplatzUebergabe>().Should().NotBeNull();
    }

    /// <summary>
    /// Beim Zeitgeber (#112) ist die Registrierung ausnahmsweise selbst die
    /// Frage: Er ist der einzige Schreibweg, den niemand auslöst. Bliebe er unter
    /// dem Not-Aus registriert, liefe in jedem Testhost ein Halbstundentakt mit,
    /// der in den OneDrive-Ordner des Anwalts schreiben will.
    /// </summary>
    [Fact]
    public void Abgeschaltet_laeuft_kein_Zeitgeber_mit()
    {
        Anbieter(eingeschaltet: false).GetServices<IHostedService>()
            .OfType<SicherungsZeitgeber>().Should().BeEmpty();
    }

    [Fact]
    public void Eingeschaltet_sichert_der_Zeitgeber_waehrend_der_Arbeit()
    {
        Anbieter(eingeschaltet: true).GetServices<IHostedService>()
            .OfType<SicherungsZeitgeber>().Should().ContainSingle();
    }

    [Fact]
    public void Ohne_Eintrag_ist_die_automatische_Sicherung_an()
    {
        var anbieter = new ServiceCollection()
            .AddLogging()
            .AddBackupServices(new ConfigurationBuilder().Build())
            .BuildServiceProvider();

        anbieter.GetRequiredService<IAutomatischeSicherung>().Should().NotBeNull();
    }

    static IAutomatischeSicherung Dienst(bool eingeschaltet) =>
        Anbieter(eingeschaltet).GetRequiredService<IAutomatischeSicherung>();

    /// <summary>
    /// Bewusst ohne Persistenz-Registrierung: Waere der Schalter wirkungslos,
    /// suchte der Dienst einen <c>AutomationDbContext</c> und der Test schluege
    /// mit genau der Frage fehl, um die es geht.
    /// </summary>
    static ServiceProvider Anbieter(bool eingeschaltet)
    {
        var konfiguration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                [BackupInjection.AutomatischeSicherungSchalter] = eingeschaltet ? "true" : "false",
            })
            .Build();

        return new ServiceCollection()
            .AddLogging()
            .AddBackupServices(konfiguration)
            .BuildServiceProvider();
    }
}
