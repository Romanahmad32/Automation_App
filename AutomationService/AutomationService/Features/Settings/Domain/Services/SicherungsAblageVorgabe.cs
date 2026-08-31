using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Liest den Ordner der Sicherungsablage aus den Einstellungen (§7.2, #39).
///
/// Anders als beim Vorlagenordner (<see cref="VorlagenOrdnerVorgabe"/>) gibt es
/// hier <em>keinen</em> Rueckfall: Leer heisst abgeschaltet. Ein geratener
/// Standardordner waere hier gefaehrlich statt bequem — die Sicherung landete
/// irgendwo, der Anwalt suchte sie am zweiten Rechner vergeblich, und die
/// Uebergabe bliebe stumm, ohne dass jemand einen Fehler saehe.
///
/// Liegt im Settings-Slice, weil es ein Einstellungswert ist; der Backup-Slice,
/// der ihn braucht, haengt ohnehin schon an den Einstellungen (Vorlagenordner,
/// Schutz der Maschinenpfade beim Import).
/// </summary>
public static class SicherungsAblageVorgabe
{
    /// <summary>
    /// Der eingestellte Ordner, getrimmt — oder eine leere Zeichenkette, wenn
    /// keiner gewaehlt ist (oder es noch gar keinen Einstellungssatz gibt).
    /// </summary>
    public static string Ermittle(AutomationDbContext db) =>
        db.KanzleiSettings.AsNoTracking()
            .FirstOrDefault(s => s.Id == KanzleiSettingsEntity.SingletonId)
            ?.SicherungsAblageOrdner.Trim() ?? string.Empty;
}
