using AutomationService.Features.EmailVersand.Domain.Persistence;
using AutomationService.Features.FormTemplates.Domain.Persistence;
using AutomationService.Features.MailboxMonitor.Domain.Persistence;
using AutomationService.Features.Mandanten.Domain.Persistence;
using AutomationService.Features.Sachgebiete.Domain.Persistence;
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
public class AutomationDbContext : DbContext
{
    public bool IsolierteSicherung { get; init; }

    readonly string _datenbank;
    readonly long _generation;

    public AutomationDbContext(DbContextOptions<AutomationDbContext> options) : base(options)
    {
        _datenbank = Database.GetDbConnection().DataSource;
        _generation = DatenbankWechsel.KontextGeneration(_datenbank);
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        if (IsolierteSicherung) return base.SaveChanges(acceptAllChangesOnSuccess);
        DatenbankWechsel.Schleuse.Wait();
        try
        {
            DatenbankWechsel.Pruefe(_datenbank, _generation);
            return base.SaveChanges(acceptAllChangesOnSuccess);
        }
        finally { DatenbankWechsel.Schleuse.Release(); }
    }

    public override async Task<int> SaveChangesAsync(
        bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        if (IsolierteSicherung) return await base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
        await DatenbankWechsel.Schleuse.WaitAsync(cancellationToken);
        try
        {
            DatenbankWechsel.Pruefe(_datenbank, _generation);
            return await base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
        }
        finally { DatenbankWechsel.Schleuse.Release(); }
    }

    public DbSet<VorgangEntity> Vorgaenge => Set<VorgangEntity>();
    public DbSet<MandantEntity> Mandanten => Set<MandantEntity>();
    public DbSet<OrdnerStatusEntity> OrdnerStatus => Set<OrdnerStatusEntity>();
    public DbSet<ImportPaketEntity> ImportPakete => Set<ImportPaketEntity>();
    public DbSet<KanzleiSettingsEntity> KanzleiSettings => Set<KanzleiSettingsEntity>();
    public DbSet<StandardSchadenspositionEntity> StandardSchadenspositionen =>
        Set<StandardSchadenspositionEntity>();
    public DbSet<FormTemplateEntity> FormTemplates => Set<FormTemplateEntity>();
    public DbSet<ReceivedReplyEntity> ReceivedReplies => Set<ReceivedReplyEntity>();
    public DbSet<VersichererEntity> Versicherer => Set<VersichererEntity>();
    public DbSet<SachgebietEntity> Sachgebiete => Set<SachgebietEntity>();
    public DbSet<VersandEintragEntity> Versandprotokoll => Set<VersandEintragEntity>();
    public DbSet<MailVorlageEntity> MailVorlagen => Set<MailVorlageEntity>();
    public DbSet<GrussformelEntity> Grussformeln => Set<GrussformelEntity>();

    public DbSet<AnredeBausteinEntity> AnredeBausteine => Set<AnredeBausteinEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Sammelt jede IEntityTypeConfiguration<> aus diesem Assembly ein — jedes
        // Feature konfiguriert sein eigenes Mapping in seinem Slice.
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AutomationDbContext).Assembly);
    }
}
