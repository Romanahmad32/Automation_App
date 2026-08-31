using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Features.Settings.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.DependencyInjection;

public static class BackupInjection
{
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
                () =>
                {
                    using var scope = sp.GetRequiredService<IServiceScopeFactory>().CreateScope();
                    return VorlagenOrdnerVorgabe.Ermittle(
                        scope.ServiceProvider.GetRequiredService<AutomationDbContext>());
                },
                sp.GetRequiredService<ILogger<DatabaseBackupService>>()));
        return services;
    }
}
