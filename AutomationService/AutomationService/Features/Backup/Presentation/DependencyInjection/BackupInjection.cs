using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.DependencyInjection;

public static class BackupInjection
{
    public static IServiceCollection AddBackupServices(this IServiceCollection services)
    {
        // Zustandslos und an die festen Pfade in %APPDATA% gebunden — Singleton.
        // Die Pfade kommen als Zeichenketten aus AppDataPaths statt als Abhängigkeit
        // auf den WordAutomation-Slice: die Sicherung muss die Vorlagen nur finden,
        // nicht verstehen.
        services.AddSingleton<IDatabaseBackupService>(sp =>
            new DatabaseBackupService(
                AppDataPaths.DatabaseFilePath(),
                AppDataPaths.EnsureVorlagenDirectory(),
                sp.GetRequiredService<ILogger<DatabaseBackupService>>()));
        return services;
    }
}
