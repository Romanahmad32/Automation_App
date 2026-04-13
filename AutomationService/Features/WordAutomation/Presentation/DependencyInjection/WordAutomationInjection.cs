using AutomationService.Features.WordAutomation.Domain.Services;

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

        return services;
    }
}
