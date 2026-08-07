using AutomationService.Core.Persistence;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Features.WordAutomation.Presentation.HostedServices;

namespace AutomationService.Features.WordAutomation.Presentation.DependencyInjection;

public static class WordAutomationInjection
{
    public static IServiceCollection AddWordServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<WordAutomationOptions>()
            .Bind(configuration.GetSection(WordAutomationOptions.SectionName))
            // TemplatesDirectory zeigt auf die *mitgelieferten* Vorlagen (relativ
            // zum ContentRoot). Sie sind Saatgut: VorlagenSeedService uebernimmt
            // sie einmalig in den Vorlagenordner des Anwenders unter %APPDATA%,
            // wo sie ein Update ueberleben. Gearbeitet wird nur dort.
            .Validate(
                options => !string.IsNullOrWhiteSpace(options.TemplatesDirectory) &&
                           !Path.IsPathRooted(options.TemplatesDirectory),
                "TemplatesDirectory must be a relative, non-empty path.")
            .Validate(
                options => !string.IsNullOrWhiteSpace(options.OutputDirectory) &&
                           !Path.IsPathRooted(options.OutputDirectory),
                "OutputDirectory must be a relative, non-empty path.")
            .ValidateOnStart();

        services.AddScoped<IWordAutomationService, WordAutomationService>();

        // Zustandslos und an den festen Ordner in %APPDATA% gebunden — Singleton.
        services.AddSingleton(sp => new VorlagenVerzeichnis(
            AppDataPaths.EnsureVorlagenDirectory(),
            sp.GetRequiredService<ILogger<VorlagenVerzeichnis>>()));
        services.AddHostedService<VorlagenSeedService>();

        services.AddHostedService<WordAutomationWarmupService>();

        return services;
    }
}
