using System.Net;
using AutomationService.Core.Lifetime;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.HostedServices;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.Aktualisierung.Presentation.DependencyInjection;

public static class AktualisierungInjection
{
    /// <summary>
    /// Verdrahtet die Aktualisierung aus der App heraus (#196). Quelle,
    /// Installer-Start und das Herunterfahren danach sind Nähte: Der
    /// E2E-Testmodus ersetzt alle drei (<c>AddDevSimulationServices</c>), Tests ebenso.
    /// </summary>
    public static IServiceCollection AddAktualisierungServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);

        services.AddOptions<AktualisierungOptions>()
            .Bind(configuration.GetSection(AktualisierungOptions.SectionName));

        services.AddHttpClient(GithubAktualisierungsQuelle.ClientName, client =>
                client.Timeout = Timeout.InfiniteTimeSpan)
            // System-Proxy gilt ohnehin; die Windows-Anmeldung dazu nicht. Ein
            // Kanzlei-Proxy mit Anmeldung (NTLM/Kerberos) antwortete sonst mit 407.
            .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
            {
                DefaultProxyCredentials = CredentialCache.DefaultCredentials,
            });

        services.AddSingleton<IAktualisierungsQuelle, GithubAktualisierungsQuelle>();
        services.AddSingleton<IInstallerStarter, InstallerStarter>();
        services.AddSingleton<IHerunterfahrenNachInstallerStart, GeordnetesHerunterfahren>();
        // Erst bei der ersten Auflösung, also nach Program.cs' Zuweisung des Datenordners.
        services.AddSingleton(_ => new AktualisierungsOrdner(AktualisierungsOrdner.Vorgabe()));
        services.AddSingleton<IAktualisierungsDienst>(provider => new AktualisierungsDienst(
            provider.GetRequiredService<IAktualisierungsQuelle>(),
            provider.GetRequiredService<IInstallerStarter>(),
            provider.GetRequiredService<IHerunterfahrenNachInstallerStart>(),
            provider.GetRequiredService<AktualisierungsOrdner>(),
            provider.GetRequiredService<IOptions<AktualisierungOptions>>(),
            provider.GetRequiredService<ILogger<AktualisierungsDienst>>(),
            Programmfassung.Aktuell));
        services.AddHostedService<AktualisierungStartDienst>();

        return services;
    }
}
