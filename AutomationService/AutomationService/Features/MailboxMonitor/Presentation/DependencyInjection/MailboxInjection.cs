using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.MailboxMonitor.Presentation.HostedServices;

namespace AutomationService.Features.MailboxMonitor.Presentation.DependencyInjection;

public static class MailboxInjection
{
    public static IServiceCollection AddMailboxServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddOptions<MailboxOptions>()
            .Bind(configuration.GetSection(MailboxOptions.SectionName))
            .Validate(
                options => options.IdleRefreshMinutes is > 0 and <= 29,
                "Mailbox:IdleRefreshMinutes must be between 1 and 29 (RFC 2177 limit).")
            .ValidateOnStart();

        // Singletons: Konfiguration und Verbindungszustand leben so lange wie der
        // Host und werden von Hintergrunddienst und Controller geteilt. Der
        // ConfigStore macht den Zugang zur Laufzeit (über die Einstellungen)
        // änderbar; appsettings.json liefert nur noch die Startwerte.
        services.AddSingleton<MailboxConfigStore>();
        services.AddSingleton<MailboxConnectionState>();

        // Microsoft-OAuth für Outlook-Postfächer: Singleton, weil MSAL-App und
        // Token-Cache (Datei) über Monitor und Controller hinweg geteilt werden.
        services.AddSingleton<MicrosoftMailOAuthService>();

        // Der Inbox-Speicher ist jetzt DB-gestützt und damit scoped (er nutzt den
        // EF-Core-Kontext). Der Singleton-Hintergrunddienst greift über einen
        // eigenen Scope darauf zu (IServiceScopeFactory).
        services.AddScoped<IReceivedReplyStore, DbReceivedReplyStore>();
        services.AddHostedService<MailboxMonitorService>();

        return services;
    }
}
