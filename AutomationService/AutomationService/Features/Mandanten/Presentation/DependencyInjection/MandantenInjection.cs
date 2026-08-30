using AutomationService.Features.Mandanten.Domain.Services;

namespace AutomationService.Features.Mandanten.Presentation.DependencyInjection;

public static class MandantenInjection
{
    public static IServiceCollection AddMandantenServices(this IServiceCollection services)
    {
        services.AddScoped<IMandantenRepository, MandantenRepository>();
        services.AddScoped<IOrdnerStatusRegister, OrdnerStatusRegister>();
        services.AddScoped<IMandantenImport, MandantenImport>();
        return services;
    }
}
