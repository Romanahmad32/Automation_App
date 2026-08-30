using AutomationService.Features.Settings.Domain.Services;

namespace AutomationService.Features.Settings.Presentation.DependencyInjection;

public static class SettingsInjection
{
    public static IServiceCollection AddSettingsServices(this IServiceCollection services)
    {
        // Scoped wie der DbContext, von dem das Repository abhängt.
        services.AddScoped<IKanzleiSettingsRepository, KanzleiSettingsRepository>();
        services.AddScoped<IStandardSchadenspositionenRepository, StandardSchadenspositionenRepository>();
        return services;
    }
}
