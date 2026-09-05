using AutomationService.Core.Persistence;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Ermittelt den Zielordner des Register-Spiegels (§6.2, #40, #103).
///
/// Drei Stufen, wie bei den uebrigen Ordnern: der eigens gewaehlte Ordner, sonst
/// der abgeleitete unter dem App-Daten-Ordner, sonst gar keiner. Leer heisst
/// hier — wie bei der Sicherungsablage — abgeschaltet: Der Spiegel wird nicht
/// geschrieben, der Export laeuft nur auf Knopfdruck.
///
/// Liegt im Settings-Slice, weil es ein Einstellungswert ist; der
/// Vorgaenge-Slice, der den Spiegel schreibt, haengt ohnehin schon an den
/// Einstellungen (Auftragsnummer beim Abschluss) — und liest den Ordner seit
/// #103 nicht mehr selbst aus dem Feld, sonst kaeme die Ableitung dort nicht an.
/// </summary>
public static class RegisterAblageVorgabe
{
    /// <inheritdoc cref="Ermittle(AutomationDbContext, Func{string, string?})"/>
    public static string Ermittle(AutomationDbContext db) => Ermittle(db, AppOrdnerPfad.Umgebung);

    /// <summary>
    /// Der wirksame Ablageordner: eingestellt, sonst
    /// <c>&lt;AppDaten&gt;\Register</c>, sonst leer.
    /// </summary>
    public static string Ermittle(AutomationDbContext db, Func<string, string?> umgebung)
    {
        var eigen = AppDatenOrdnerVorgabe.Aufgeloest(db, satz => satz.RegisterAblageOrdner, umgebung);
        return eigen.Length > 0
            ? eigen
            : AppDatenOrdnerVorgabe.Abgeleitet(db, AppDatenOrdnerVorgabe.RegisterUnterordner, umgebung);
    }
}
