using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Atomarer Vorgangsabschluss: Statuswechsel und Auftragsnummer laufen über
/// denselben DbContext und ein einziges SaveChanges — EF Core schreibt das als
/// eine SQLite-Transaktion, ein Teilfehler lässt beides unverändert.
/// </summary>
public sealed class VorgangAbschlussService(AutomationDbContext db) : IVorgangAbschlussService
{
    /// <summary>Persistierter Statuswert; muss zum Flutter-Enum VorgangStatus passen.</summary>
    public const string StatusVersendet = "versendet";

    public async Task<VorgangEntity?> AbschliessenAsync(
        string referenz,
        CancellationToken cancellationToken = default)
    {
        var bereinigt = referenz.Trim();
        var vorgang = await db.Vorgaenge
            .FirstOrDefaultAsync(v => v.Referenz == bereinigt, cancellationToken);
        if (vorgang is null) return null;
        if (vorgang.Status == StatusVersendet) return vorgang;

        vorgang.Status = StatusVersendet;
        vorgang.AbgeschlossenAm = DateTime.Now;

        var settings = await db.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken);
        if (settings is null)
        {
            settings = KanzleiSettingsRepository.CreateDefault();
            db.KanzleiSettings.Add(settings);
        }
        settings.LaufendeAuftragsnummer += 1;

        await db.SaveChangesAsync(cancellationToken);
        return vorgang;
    }
}
