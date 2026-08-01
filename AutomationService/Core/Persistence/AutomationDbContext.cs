using AutomationService.Features.FormTemplates.Domain.Persistence;
using AutomationService.Features.MailboxMonitor.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Versicherer.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Core.Persistence;

/// <summary>
/// Zentraler EF-Core-Kontext über der eingebetteten SQLite-Datenbank
/// (%APPDATA%\AutomationService\automation.db). Einziger Schreiber: nur das
/// Backend öffnet die Datei, das Frontend greift ausschließlich über HTTP zu.
/// Das macht Transaktionen serialisierbar und schließt die früheren
/// Lost-Update-Races der parallel schreibenden JSON-Speicher aus.
///
/// Der Context bündelt zwingend alle DbSet&lt;&gt; (EF erlaubt keinen verteilten
/// Context). Das Schema-Mapping liegt aber je beim Feature
/// (IEntityTypeConfiguration) und wird hier nur eingesammelt.
/// </summary>
public class AutomationDbContext(DbContextOptions<AutomationDbContext> options)
    : DbContext(options)
{
    public DbSet<VorgangEntity> Vorgaenge => Set<VorgangEntity>();
    public DbSet<MandantEntity> Mandanten => Set<MandantEntity>();
    public DbSet<KanzleiSettingsEntity> KanzleiSettings => Set<KanzleiSettingsEntity>();
    public DbSet<FormTemplateEntity> FormTemplates => Set<FormTemplateEntity>();
    public DbSet<ReceivedReplyEntity> ReceivedReplies => Set<ReceivedReplyEntity>();
    public DbSet<VersichererEntity> Versicherer => Set<VersichererEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Sammelt jede IEntityTypeConfiguration<> aus diesem Assembly ein — jedes
        // Feature konfiguriert sein eigenes Mapping in seinem Slice.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AutomationDbContext).Assembly);
    }
}
