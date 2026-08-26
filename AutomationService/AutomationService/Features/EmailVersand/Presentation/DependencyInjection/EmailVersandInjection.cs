using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.DependencyInjection;

public static class EmailVersandInjection
{
    public static IServiceCollection AddEmailVersandServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<EmailVersandOptions>()
            .Bind(configuration.GetSection(EmailVersandOptions.SectionName))
            .Validate(
                optionen => optionen.SmtpPort is > 0 and <= 65535,
                "EmailVersand:SmtpPort muss ein gültiger Port sein.")
            .Validate(
                optionen => optionen.MaxAnhangGesamtMb > 0,
                "EmailVersand:MaxAnhangGesamtMb muss größer als 0 sein.")
            .ValidateOnStart();

        services.AddScoped<GesendetOrdnerAblage>();
        services.AddScoped<KanzleiSignatur>();
        services.AddScoped<OutlookEntwurf>();
        services.AddScoped<EntwurfDatei>();
        services.AddScoped<IEntwurfOeffner, EntwurfOeffner>();
        services.AddScoped<IEmailVersender, SmtpEmailVersender>();
        return services;
    }
}
