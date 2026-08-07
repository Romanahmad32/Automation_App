using AutomationService.Core.Lifetime;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Sichert die beiden Entscheidungen ab, die den Dienst als Teil der
/// Desktop-Anwendung ausmachen: Er faehrt mit dem Frontend herunter — aber nur
/// dann, wenn ihn auch wirklich ein Frontend gestartet hat. Ein versehentlich
/// immer registrierter Waechter wuerde den Dienst beim Entwickeln
/// (<c>dotnet run</c>, ohne --parent-pid) sofort wieder beenden.
/// </summary>
public class LifetimeInjectionTests
{
    [Theory]
    [InlineData("4711")]
    [InlineData("1")]
    public void Waechter_wird_mit_gueltiger_ParentPid_registriert(string parentPid)
    {
        var services = Registriere(parentPid);

        AnzahlHostedServices(services).Should().Be(1,
            "mit --parent-pid soll der Dienst an den Elternprozess gekoppelt sein");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("0")]
    [InlineData("-1")]
    [InlineData("keine-zahl")]
    public void Waechter_wird_ohne_brauchbare_ParentPid_nicht_registriert(string? parentPid)
    {
        var services = Registriere(parentPid);

        AnzahlHostedServices(services).Should().Be(0,
            "ohne Elternprozess muss der Dienst eigenstaendig weiterlaufen");
    }

    [Fact]
    public void Bereitschaft_ist_zu_Beginn_nicht_gesetzt()
    {
        var readiness = Registriere(null)
            .BuildServiceProvider()
            .GetRequiredService<ApplicationReadiness>();

        readiness.IstBereit.Should().BeFalse();

        readiness.MarkiereBereit();

        readiness.IstBereit.Should().BeTrue();
    }

    private static ServiceCollection Registriere(string? parentPid)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                [LifetimeInjection.ParentPidArgument] = parentPid
            })
            .Build();

        var services = new ServiceCollection();
        services.AddLogging();
        services.AddLifetimeServices(configuration);
        return services;
    }

    private static int AnzahlHostedServices(IServiceCollection services) =>
        services.Count(descriptor => descriptor.ServiceType == typeof(IHostedService));
}
