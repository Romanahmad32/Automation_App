using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.EmailVersand.Presentation.HostedServices;

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
        // Singleton: Der Dienst haelt einen STA-Thread und die
        // Outlook-Instanz am Leben — je Anfrage neu aufzubauen hiesse, den
        // Kaltstart jedes Mal zu bezahlen.
        services.AddSingleton<OutlookVerbindung>();
        services.AddSingleton<AnhangAblage>();
        services.AddHostedService<AnhangAufraeumService>();
        services.AddScoped<EntwurfDatei>();
        services.AddScoped<IEntwurfOeffner, EntwurfOeffner>();
        services.AddScoped<IEmailVersender, SmtpEmailVersender>();
        return services;
    }
}
