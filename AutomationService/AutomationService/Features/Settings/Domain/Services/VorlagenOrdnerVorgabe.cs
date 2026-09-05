using AutomationService.Core.Persistence;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Ermittelt den Vorlagenordner aus den Einstellungen (#33, #103). Drei Stufen:
/// der eigens gewaehlte Ordner, sonst der abgeleitete unter dem App-Daten-Ordner
/// (<c>&lt;AppDaten&gt;\Vorlagen</c>), sonst der App-Ordner unter %APPDATA% —
/// der Stand vor der Einstellung, damit ein Bestand ohne gesetzten Ordner
/// unveraendert weiterlaeuft.
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
    /// <inheritdoc cref="Eingestellt(AutomationDbContext, Func{string, string?})"/>
    public static string Eingestellt(AutomationDbContext db) =>
        Eingestellt(db, AppOrdnerPfad.Umgebung);

    /// <summary>
    /// Der vom Anwalt bestimmte Ordner — eigens gewaehlt oder aus dem
    /// App-Daten-Ordner abgeleitet — oder leer, wenn er keinen bestimmt hat.
    /// Fuer Aufrufer, die wissen muessen, ob der Anwalt selbst gewaehlt hat
    /// (der Seed-Dienst saet nur in den App-Ordner, nie in einen gewaehlten).
    /// </summary>
    public static string Eingestellt(AutomationDbContext db, Func<string, string?> umgebung)
    {
        var eigen = AppDatenOrdnerVorgabe.Aufgeloest(db, satz => satz.VorlagenOrdner, umgebung);
        return eigen.Length > 0
            ? eigen
            : AppDatenOrdnerVorgabe.Abgeleitet(db, AppDatenOrdnerVorgabe.VorlagenUnterordner, umgebung);
    }

    /// <inheritdoc cref="Ermittle(AutomationDbContext, Func{string, string?})"/>
    public static string Ermittle(AutomationDbContext db) => Ermittle(db, AppOrdnerPfad.Umgebung);

    /// <summary>Der wirksame Ordner: bestimmt, sonst der App-Ordner.</summary>
    public static string Ermittle(AutomationDbContext db, Func<string, string?> umgebung)
    {
        var eingestellt = Eingestellt(db, umgebung);
        return eingestellt.Length > 0 ? eingestellt : AppDataPaths.EnsureVorlagenDirectory();
    }
}
