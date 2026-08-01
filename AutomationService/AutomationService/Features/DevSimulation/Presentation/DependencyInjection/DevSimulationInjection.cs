using AutomationService.Features.DevSimulation.Domain.Services;

namespace AutomationService.Features.DevSimulation.Presentation.DependencyInjection;

public static class DevSimulationInjection
{
    public static IServiceCollection AddDevSimulationServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<SimulationOptions>()
            .Bind(configuration.GetSection(SimulationOptions.SectionName));

        return services;
    }
}
