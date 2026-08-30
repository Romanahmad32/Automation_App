using AutomationService.Core.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;

namespace AutomationService.Features.Vorgaenge.Presentation.DependencyInjection;

public static class VorgaengeInjection
{
    public static IServiceCollection AddVorgaengeServices(this IServiceCollection services)
    {
        services.AddScoped<IVorgangRepository, VorgangRepository>();
        services.AddScoped<IVorgangAbschlussService, VorgangAbschlussService>();

        // Bauordner und Stand haengen an festen Pfaden und halten keinen
        // Zustand je Anfrage — Singleton. Beide liegen neben der Datenbank und
        // nicht im Ablageordner: Was dort landet, synchronisiert mit und waere
        // auf dem Handy als Fremddatei sichtbar.
        services.AddSingleton(_ => new RegisterSpiegelBauordner(
            Path.Combine(AppDataPaths.EnsureAppDataDirectory(), "RegisterBau")));
        services.AddSingleton(_ => new RegisterSpiegelStand(
            Path.Combine(AppDataPaths.EnsureAppDataDirectory(), "register-spiegel.stand.json")));
        services.AddScoped<IRegisterSpiegelService, RegisterSpiegelService>();

        return services;
    }
}
