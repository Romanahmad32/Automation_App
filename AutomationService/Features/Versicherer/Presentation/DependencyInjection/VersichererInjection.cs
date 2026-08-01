using AutomationService.Features.Versicherer.Domain.Services;

namespace AutomationService.Features.Versicherer.Presentation.DependencyInjection;

public static class VersichererInjection
{
    public static IServiceCollection AddVersichererServices(this IServiceCollection services)
    {
        services.AddScoped<IVersichererWissen, VersichererWissen>();
        return services;
    }
}
