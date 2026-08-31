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
///
/// Danach — und ausdrücklich erst danach — wird der Register-Spiegel neu
/// geschrieben (§6.2, #40). Die Reihenfolge ist die eigentliche Zusicherung:
/// Ein gesperrter Ablageordner, ein fehlendes Word oder ein voll gelaufenes
/// Laufwerk dürfen einen abgeschlossenen Auftrag nicht wieder aufmachen. Der
/// Spiegel ist eine Kopie; die Datenbank ist das Register.
/// </summary>
/// <param name="db">Vorgänge und Einstellungen in einer Transaktion.</param>
/// <param name="spiegel">Schreibt die Word-/PDF-Fassung; wirft nicht.</param>
/// <param name="logger">Hält fest, wenn der Spiegel nicht geschrieben werden konnte.</param>
public sealed class VorgangAbschlussService(
    AutomationDbContext db,
    IRegisterSpiegelService spiegel,
    ILogger<VorgangAbschlussService> logger) : IVorgangAbschlussService
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

        if (settings.RegisterNachAbschlussSchreiben)
        {
            await SpiegelNachziehenAsync(cancellationToken);
        }

        return vorgang;
    }

    /// <summary>
    /// Zieht den Register-Spiegel nach. Der Aufruf ist doppelt abgesichert: Der
    /// Dienst meldet erwartbare Fehlschläge als Ergebnis statt als Ausnahme,
    /// und was trotzdem herauskommt, wird hier geschluckt. Der Abschluss ist
    /// zu diesem Zeitpunkt festgeschrieben und darf nicht mehr wackeln.
    /// </summary>
    async Task SpiegelNachziehenAsync(CancellationToken cancellationToken)
    {
        try
        {
            var ergebnis = await spiegel.SchreibeAsync(cancellationToken: cancellationToken);
            if (ergebnis.Fehler is not null)
            {
                logger.LogWarning(
                    "Register-Spiegel nach Abschluss nicht geschrieben: {Fehler}", ergebnis.Fehler);
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Register-Spiegel nach Abschluss unerwartet fehlgeschlagen.");
        }
    }
}
