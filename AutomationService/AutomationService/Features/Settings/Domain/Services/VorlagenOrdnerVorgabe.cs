using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Ermittelt den Vorlagenordner aus den Einstellungen (#33). Leer heisst: der
/// App-Ordner unter %APPDATA% — der Stand vor der Einstellung, damit ein
/// Bestand ohne gesetzten Ordner unveraendert weiterlaeuft.
///
/// Liegt wie <see cref="RegisterSpiegelVorgabe"/> im Settings-Slice, weil es
/// ein Einstellungswert ist; WordAutomation und Backup haengen fuer die
/// Aufloesung hieran statt an einer fest verdrahteten Konstante.
///
/// Bewusst synchron: die Aufrufer sind DI-Factories und Scope-Bloecke, die
/// nicht awaiten koennen, und gelesen wird eine einzelne Zeile aus SQLite.
/// </summary>
public static class VorlagenOrdnerVorgabe
{
    /// <summary>
    /// Der eingestellte Ordner, getrimmt — oder leer, wenn keiner gesetzt ist.
    /// Fuer Aufrufer, die wissen muessen, ob der Anwalt selbst gewaehlt hat
    /// (der Seed-Dienst saet nur in den App-Ordner, nie in einen gewaehlten).
    /// </summary>
    public static string Eingestellt(AutomationDbContext db) =>
        db.KanzleiSettings.AsNoTracking()
            .FirstOrDefault(s => s.Id == KanzleiSettingsEntity.SingletonId)
            ?.VorlagenOrdner.Trim() ?? string.Empty;

    /// <summary>Der wirksame Ordner: eingestellt, sonst der App-Ordner.</summary>
    public static string Ermittle(AutomationDbContext db)
    {
        var eingestellt = Eingestellt(db);
        return eingestellt.Length > 0 ? eingestellt : AppDataPaths.EnsureVorlagenDirectory();
    }
}
