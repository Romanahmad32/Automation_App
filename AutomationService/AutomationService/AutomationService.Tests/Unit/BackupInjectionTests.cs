using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Backup.Presentation.DependencyInjection;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
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
