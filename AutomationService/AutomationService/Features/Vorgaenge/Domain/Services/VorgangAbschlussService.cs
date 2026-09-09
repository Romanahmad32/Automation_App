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
///
/// Seit dem 09.09.2026 gilt dasselbe für den Spiegel (§4.8: „Er wartet nicht
/// mehr darauf, dass die Register-Dateien geschrieben sind"). Er ist die
/// dritte Nebensache an derselben Stelle, und aus demselben Grund abgesetzt:
/// Die Datenbank ist das Register, die Dateien sind die Kopie. Die Wandlung
/// nach PDF hat der Spiegel selbst schon abgesetzt (§6.2 „Word sofort, PDF
/// nachgezogen") — nur schreibt er die .docx davor noch synchron, und auch die
/// muss der Abschluss nicht abwarten, um festzustehen.
/// </summary>
/// <param name="db">Vorgänge und Einstellungen in einer Transaktion.</param>
/// <param name="scopes">
/// Liefert dem abgesetzten Spiegel-Lauf seinen eigenen Scope — warum er einen
/// braucht, steht an <see cref="StosseSpiegelAn"/>.
/// </param>
/// <param name="sicherung">Legt den Stand im synchronisierten Ordner ab; wirft nicht.</param>
/// <param name="logger">Hält fest, wenn der Spiegel nicht geschrieben werden konnte.</param>
public sealed class VorgangAbschlussService(
    AutomationDbContext db,
    IServiceScopeFactory scopes,
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
            StosseSpiegelAn();
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
    /// Stößt den Register-Spiegel an und lässt ihn laufen (§4.8: der Abschluss
    /// wartet nicht mehr darauf, dass die Register-Dateien geschrieben sind).
    ///
    /// Bewusst ohne <c>await</c> und bewusst ohne den Abbruch-Token des
    /// Requests — aus demselben Grund wie bei
    /// <see cref="StosseSicherungAn"/>: Die Antwort geht sofort hinaus, und
    /// mit ihr wäre der Token abgebrochen; der Spiegel stürbe genau in dem
    /// Moment, für den er da ist.
    ///
    /// Ein Unterschied zur Sicherung bleibt, und er ist der Grund für den
    /// eigenen Scope: Der Spiegel ist <em>kein</em> Singleton. Er liest die
    /// Vorgänge über einen <c>DbContext</c>, der am Scope dieses Requests
    /// hängt, und den räumt der Container mit der Antwort ab. Ohne eigenen
    /// Scope fände der abgesetzte Lauf statt der Zeilen ein „Cannot access a
    /// disposed context instance" — und weil der Spiegel Fehlschläge als
    /// Ergebnis meldet statt zu werfen, bliebe der Ablageordner still leer.
    ///
    /// Doppelt abgesichert wie vorher: Der Dienst meldet erwartbare
    /// Fehlschläge als Ergebnis, und was trotzdem herauskommt, wird hier
    /// geschluckt. Der Abschluss ist zu diesem Zeitpunkt festgeschrieben und
    /// darf nicht mehr wackeln.
    /// </summary>
    void StosseSpiegelAn() => _ = Task.Run(async () =>
    {
        try
        {
            using var scope = scopes.CreateScope();
            var spiegel = scope.ServiceProvider.GetRequiredService<IRegisterSpiegelService>();
            var ergebnis = await spiegel.SchreibeAsync();
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
    });
}
