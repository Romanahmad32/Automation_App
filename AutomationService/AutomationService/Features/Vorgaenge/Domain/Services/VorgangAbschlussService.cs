using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
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
///
/// Ebenfalls danach, aber <em>ohne</em> darauf zu warten: die automatische
/// Sicherung (§7.2, #39). Sie ist die zweite Nebensache an derselben Stelle —
/// nur eine, die spürbar dauert (Datenbank kopieren, Vorlagen packen, in einen
/// synchronisierten Ordner schreiben). Der Anwalt würde das als zähen
/// „Abschließen"-Knopf erleben, und der Abschluss steht zu diesem Zeitpunkt
/// ohnehin fest. Der Fehlschlag wird gemerkt und beim nächsten Start gezeigt.
/// </summary>
/// <param name="db">Vorgänge und Einstellungen in einer Transaktion.</param>
/// <param name="spiegel">Schreibt die Word-/PDF-Fassung; wirft nicht.</param>
/// <param name="sicherung">Legt den Stand im synchronisierten Ordner ab; wirft nicht.</param>
/// <param name="logger">Hält fest, wenn der Spiegel nicht geschrieben werden konnte.</param>
public sealed class VorgangAbschlussService(
    AutomationDbContext db,
    IRegisterSpiegelService spiegel,
    IAutomatischeSicherung sicherung,
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

        StosseSicherungAn();
        return vorgang;
    }

    /// <summary>
    /// Startet die automatische Sicherung und lässt sie laufen.
    ///
    /// Bewusst ohne <c>await</c> und bewusst ohne den Abbruch-Token des
    /// Requests: Die Antwort geht sofort hinaus, und mit ihr wäre der Token
    /// abgebrochen — die Sicherung stürbe genau in dem Moment, für den sie da
    /// ist. Der Dienst dahinter ist ein Singleton und hängt nicht am Scope
    /// dieses Requests; er meldet Fehlschläge selbst und wirft nicht.
    /// </summary>
    void StosseSicherungAn() => _ = Task.Run(async () =>
    {
        try
        {
            await sicherung.SchreibeAsync();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Automatische Sicherung nach Abschluss fehlgeschlagen.");
        }
    });

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
