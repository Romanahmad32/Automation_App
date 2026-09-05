using AutomationService.Core.Persistence;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Ermittelt den Ordner der Sicherungsablage (§7.2, #39, #103): der eigens
/// gewaehlte Ordner, sonst der abgeleitete unter dem App-Daten-Ordner
/// (<c>&lt;AppDaten&gt;\Sicherungen</c>), sonst keiner.
///
/// Anders als beim Vorlagenordner (<see cref="VorlagenOrdnerVorgabe"/>) gibt es
/// hier <em>keinen</em> Rueckfall auf %APPDATA%: Leer heisst abgeschaltet. Ein
/// geratener Standardordner waere hier gefaehrlich statt bequem — die Sicherung
/// landete irgendwo, der Anwalt suchte sie am zweiten Rechner vergeblich, und
/// die Uebergabe bliebe stumm, ohne dass jemand einen Fehler saehe. Der
/// abgeleitete Ordner ist kein solcher Rateversuch: Er steht unter einem
/// Ordner, den der Anwalt selbst gewaehlt hat.
///
/// Liegt im Settings-Slice, weil es ein Einstellungswert ist; der Backup-Slice,
/// der ihn braucht, haengt ohnehin schon an den Einstellungen (Vorlagenordner,
/// Schutz der Maschinenpfade beim Import).
/// </summary>
public static class SicherungsAblageVorgabe
{
    /// <inheritdoc cref="Ermittle(AutomationDbContext, Func{string, string?})"/>
    public static string Ermittle(AutomationDbContext db) => Ermittle(db, AppOrdnerPfad.Umgebung);

    /// <summary>
    /// Der wirksame Ablageordner — oder eine leere Zeichenkette, wenn keiner
    /// gewaehlt und keiner abzuleiten ist (oder es noch gar keinen
    /// Einstellungssatz gibt).
    /// </summary>
    public static string Ermittle(AutomationDbContext db, Func<string, string?> umgebung)
    {
        var eigen = AppDatenOrdnerVorgabe.Aufgeloest(db, satz => satz.SicherungsAblageOrdner, umgebung);
        return eigen.Length > 0
            ? eigen
            : AppDatenOrdnerVorgabe.Abgeleitet(db, AppDatenOrdnerVorgabe.SicherungenUnterordner, umgebung);
    }
}
