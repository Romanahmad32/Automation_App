using AutomationService.Features.Sachgebiete.Domain.Services;

namespace AutomationService.Features.Sachgebiete.Presentation.DependencyInjection;

public static class SachgebieteInjection
{
    public static IServiceCollection AddSachgebieteServices(this IServiceCollection services)
    {
        services.AddScoped<ISachgebietKatalog, SachgebietKatalog>();
        return services;
    }
}
