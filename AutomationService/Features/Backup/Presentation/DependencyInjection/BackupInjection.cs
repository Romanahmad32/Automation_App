using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;

namespace AutomationService.Features.Backup.Presentation.DependencyInjection;

public static class BackupInjection
{
    public static IServiceCollection AddBackupServices(this IServiceCollection services)
    {
        // Zustandslos und an die feste DB-Datei in %APPDATA% gebunden — Singleton.
        services.AddSingleton<IDatabaseBackupService>(sp =>
            new DatabaseBackupService(
                AppDataPaths.DatabaseFilePath(),
                sp.GetRequiredService<ILogger<DatabaseBackupService>>()));
        return services;
    }
}
