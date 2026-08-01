using Microsoft.EntityFrameworkCore;

namespace AutomationService.Core.Persistence.HostedServices;

/// <summary>
/// Bringt die SQLite-Datenbank beim Start auf den aktuellen Schemastand und
/// aktiviert den WAL-Journalmodus. Läuft — anders als die Warmup-Dienste —
/// <em>blockierend</em> im StartAsync, bevor der Host Requests annimmt: die
/// übrigen Dienste (Postfach-Monitor, Controller) dürfen erst auf eine fertig
/// migrierte Datenbank zugreifen.
/// </summary>
public sealed class DatabaseMigrationService(
    IServiceScopeFactory scopeFactory,
    ILogger<DatabaseMigrationService> logger) : IHostedService
{
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AutomationDbContext>();

        await dbContext.Database.MigrateAsync(cancellationToken);

        // WAL erlaubt gleichzeitiges Lesen während eines Schreibvorgangs und ist
        // robuster gegen Abstürze. Einmal gesetzt, bleibt der Modus persistent in
        // der Datei — das erneute Setzen bei jedem Start ist unschädlich.
        await dbContext.Database.ExecuteSqlRawAsync("PRAGMA journal_mode=WAL;", cancellationToken);

        logger.LogInformation("SQLite-Datenbank migriert und einsatzbereit (WAL aktiv).");
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
