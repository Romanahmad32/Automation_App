using AutomationService.Features.FormTemplates.Domain.Services;

namespace AutomationService.Features.FormTemplates.Presentation.DependencyInjection;

public static class FormTemplatesInjection
{
    public static IServiceCollection AddFormTemplatesServices(this IServiceCollection services)
    {
        services.AddScoped<IFormTemplateRepository, FormTemplateRepository>();
        return services;
    }
}
