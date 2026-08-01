using AutomationService.Features.Vorgaenge.Domain.Services;

namespace AutomationService.Features.Vorgaenge.Presentation.DependencyInjection;

public static class VorgaengeInjection
{
    public static IServiceCollection AddVorgaengeServices(this IServiceCollection services)
    {
        services.AddScoped<IVorgangRepository, VorgangRepository>();
        services.AddScoped<IVorgangAbschlussService, VorgangAbschlussService>();
        return services;
    }
}
