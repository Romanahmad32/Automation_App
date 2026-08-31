using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Backup.Presentation.HostedServices;
using AutomationService.Features.Settings.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.DependencyInjection;

public static class BackupInjection
{
    /// <summary>
    /// Merker des letzten automatischen Sicherungslaufs (#39). Neben der
    /// Datenbank in %APPDATA% und ausdruecklich nicht darin: Ein Import ersetzt
    /// die Datenbankdatei, und dann waere ausgerechnet die Auskunft weg, ob die
    /// eigene Sicherung zuletzt gelungen ist.
    /// </summary>
    public const string MerkerDateiname = "letzte-sicherung.json";

    public static IServiceCollection AddBackupServices(this IServiceCollection services)
    {
        // Zustandslos — Singleton. Die Pfade kommen als Zeichenketten statt als
        // Abhängigkeit auf den WordAutomation-Slice: die Sicherung muss die
        // Vorlagen nur finden, nicht verstehen. Der Vorlagenordner ist eine
        // Einstellung (#33), deshalb eine Funktion, die je Operation über einen
        // eigenen Scope aus der Datenbank liest.
        services.AddSingleton<IDatabaseBackupService>(sp =>
            new DatabaseBackupService(
                AppDataPaths.DatabaseFilePath(),
                () => AusDenEinstellungen(sp, VorlagenOrdnerVorgabe.Ermittle),
                sp.GetRequiredService<ILogger<DatabaseBackupService>>()));

        services.AddSingleton(new LetzteSicherungAkte(
            Path.Combine(AppDataPaths.EnsureAppDataDirectory(), MerkerDateiname)));

        // Derselbe Grund für dieselbe Funktion: Die Sicherungsablage ist eine
        // Einstellung (#39) und wird je Lauf neu aufgelöst.
        services.AddSingleton<IAutomatischeSicherung>(sp =>
            new AutomatischeSicherung(
                sp.GetRequiredService<IDatabaseBackupService>(),
                sp.GetRequiredService<LetzteSicherungAkte>(),
                () => AusDenEinstellungen(sp, SicherungsAblageVorgabe.Ermittle),
                sp.GetRequiredService<ILogger<AutomatischeSicherung>>()));

        services.AddHostedService<ArbeitsplatzDienst>();
        return services;
    }

    /// <summary>
    /// Liest einen Einstellungswert über einen eigenen Scope. Die Nutzer sind
    /// Singletons, der DbContext ist Scoped — ohne diesen Umweg hielte ein
    /// Singleton den ersten Kontext für immer fest.
    /// </summary>
    static string AusDenEinstellungen(
        IServiceProvider sp, Func<AutomationDbContext, string> lies)
    {
        using var scope = sp.GetRequiredService<IServiceScopeFactory>().CreateScope();
        return lies(scope.ServiceProvider.GetRequiredService<AutomationDbContext>());
    }
}
