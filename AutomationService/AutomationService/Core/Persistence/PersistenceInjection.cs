using AutomationService.Core.Persistence.HostedServices;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Core.Persistence;

/// <summary>
/// Verdrahtet die SQLite-Persistenz: den EF-Core-Kontext auf der Datei in
/// %APPDATA%\AutomationService und den Migrationsdienst, der das Schema beim
/// Start anlegt/aktualisiert. Folgt dem Add…Services-Muster der Features.
/// </summary>
public static class PersistenceInjection
{
    public static IServiceCollection AddPersistenceServices(this IServiceCollection services)
    {
        var connectionString = $"Data Source={AppDataPaths.DatabaseFilePath()}";

        services.AddDbContext<AutomationDbContext>(options =>
            options.UseSqlite(connectionString));

        // Reihenfolge zählt: Hosted Services starten in Registrierungsreihenfolge.
        // Erst migrieren (Schema anlegen), dann den Alt-Stand importieren.
        services.AddHostedService<DatabaseMigrationService>();
        services.AddHostedService<LegacyJsonImportService>();

        return services;
    }
}
