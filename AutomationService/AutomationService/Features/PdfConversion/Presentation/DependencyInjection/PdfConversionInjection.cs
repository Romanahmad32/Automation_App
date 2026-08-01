using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.PdfConversion.Presentation.HostedServices;

namespace AutomationService.Features.PdfConversion.Presentation.DependencyInjection;

public static class PdfConversionInjection
{
    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    public static IServiceCollection AddPdfConversionServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<PdfConversionOptions>()
            .Bind(configuration.GetSection(PdfConversionOptions.SectionName))
            .Validate(
                options => options.Engine is PdfConversionOptions.EngineWordInterop
                    or PdfConversionOptions.EngineFreeSpire,
                $"Engine must be \"{PdfConversionOptions.EngineWordInterop}\" or \"{PdfConversionOptions.EngineFreeSpire}\".")
            .Validate(
                options => !string.IsNullOrWhiteSpace(options.CacheDirectory) &&
                           !Path.IsPathRooted(options.CacheDirectory),
                "CacheDirectory must be a relative, non-empty path.")
            .Validate(
                options => options.ConversionTimeoutSeconds > 0,
                "ConversionTimeoutSeconds must be positive.")
            .ValidateOnStart();

        services.AddSingleton<WordInteropPdfConversionService>();
        services.AddSingleton<IWordInteropPdfConverter>(provider =>
            provider.GetRequiredService<WordInteropPdfConversionService>());
        services.AddKeyedSingleton<IPdfConversionService, PdfConversionService>(
            CompositePdfConversionService.FreeSpireKey);
        services.AddSingleton<IPdfPreviewCache, PdfPreviewCache>();
        services.AddSingleton<IPdfConversionService, CompositePdfConversionService>();
        services.AddHostedService<PdfConversionWarmupService>();

        return services;
    }
}
