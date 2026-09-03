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

        services.AddScoped<IGesendetOrdnerAblage, GesendetOrdnerAblage>();
        services.AddScoped<ISmtpUebergabe, SmtpUebergabe>();
        services.AddScoped<KanzleiSignatur>();
        services.AddScoped<VersandProtokoll>();
        services.AddScoped<SignaturUebernahme>();
        // Singleton: Der Dienst haelt einen STA-Thread und die
        // Outlook-Instanz am Leben — je Anfrage neu aufzubauen hiesse, den
        // Kaltstart jedes Mal zu bezahlen.
        services.AddSingleton<OutlookVerbindung>();
        services.AddSingleton<AnhangAblage>();
        // Singleton fuer die Abfrage, Hosted Service fuers Erzeugen: So laeuft
        // die Erkennung beim Hochfahren und nicht erst beim ersten Klick.
        services.AddSingleton<OutlookErkennung>();
        services.AddHostedService(sp => sp.GetRequiredService<OutlookErkennung>());
        services.AddSingleton<SignaturAblage>();
        services.AddHostedService<AnhangAufraeumService>();
        services.AddScoped<EntwurfDatei>();
        services.AddScoped<IEntwurfOeffner, EntwurfOeffner>();
        services.AddScoped<IEmailVersender, SmtpEmailVersender>();
        services.AddScoped<IMailVorlagenRepository, MailVorlagenRepository>();
        services.AddScoped<IGrussformelnRepository, GrussformelnRepository>();
        services.AddScoped<IAnredeBausteineRepository, AnredeBausteineRepository>();
        return services;
    }
}
