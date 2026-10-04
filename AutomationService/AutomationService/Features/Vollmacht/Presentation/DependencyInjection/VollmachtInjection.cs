using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.Vollmacht.Presentation.HostedServices;

namespace AutomationService.Features.Vollmacht.Presentation.DependencyInjection;

public static class VollmachtInjection
{
    /// <summary>
    /// Verdrahtet den Vollmacht-Schnitt (§4.11). Setzt <c>AddWordServices</c> und
    /// <c>AddPdfConversionServices</c> voraus: Ausgefüllt wird mit dem
    /// Dokumentenerzeuger, gedruckt über den Word-Thread der PDF-Erzeugung.
    /// </summary>
    public static IServiceCollection AddVollmachtServices(this IServiceCollection services)
    {
        // Scoped wie das VorlagenVerzeichnis: Der Vorlagenordner ist eine
        // Einstellung und kann sich zur Laufzeit ändern (#33).
        services.AddScoped(sp => new VollmachtVorlagenOrdner(
            VorlagenOrdnerVorgabe.Ermittle(sp.GetRequiredService<AutomationDbContext>()),
            sp.GetRequiredService<ILogger<VollmachtVorlagenOrdner>>()));
        services.AddScoped<IVollmachtDienst, VollmachtDienst>();
        services.AddHostedService<VollmachtVorlagenSeedService>();
        return services;
    }
}
