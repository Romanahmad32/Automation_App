using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Presentation.HostedServices;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.DependencyInjection;

public static class ZentralrufInjection
{
    public static IServiceCollection AddZentralrufServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<ZentralrufOptions>()
            .Bind(configuration.GetSection(ZentralrufOptions.SectionName))
            .Validate(
                options => Uri.TryCreate(options.FormUrl, UriKind.Absolute, out _),
                "FormUrl must be an absolute URL.")
            .ValidateOnStart();

        // Singleton, damit das Browserfenster über den Request hinaus offen bleibt.
        services.AddSingleton<IZentralrufAutomationService, ZentralrufAutomationService>();
        services.AddSingleton<IZentralrufReplyParser, ZentralrufReplyParser>();
        services.AddHostedService<ZentralrufWarmupService>();

        return services;
    }
}
