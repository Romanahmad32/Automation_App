using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Der eine Ordner, unter dem die App alles ablegt, was sie ablegt (#103) —
/// und die Unterordner, die daraus <em>abgeleitet</em> statt eingestellt
/// werden.
///
/// Vorher waehlte der Anwalt vier Ordner einzeln, jeden ueber einen eigenen
/// Dialog, und musste dabei selbst wissen, welcher wozu gehoert. Der Ort ist
/// aber laengst entschieden: Er liegt im synchronisierten Bereich. Aus vier
/// Wahlen wird deshalb eine, und darunter entstehen beim ersten Schreiben
/// <see cref="VorlagenUnterordner"/>, <see cref="RegisterUnterordner"/> und
/// <see cref="SicherungenUnterordner"/>.
///
/// Der Akten-Stammordner bleibt bewusst eine eigene Wahl: Er zeigt auf die
/// gewachsene Ablage der Kanzlei (#19), die nicht unter einen neuen App-Ordner
/// gehoert.
///
/// Bewusst synchron und statisch wie die uebrigen Vorgaben dieses Slices: Die
/// Aufrufer sind DI-Factories und Scope-Bloecke, die nicht awaiten koennen,
/// und gelesen wird eine einzelne Zeile aus SQLite.
/// </summary>
public static class AppDatenOrdnerVorgabe
{
    /// <summary>Word-Vorlagen des Anwalts (#33).</summary>
    public const string VorlagenUnterordner = "Vorlagen";

    /// <summary>Register-Spiegel (§6.2, #40).</summary>
    public const string RegisterUnterordner = "Register";

    /// <summary>Automatische Sicherung und Arbeitsplatz-Uebergabe (§7.2, #39).</summary>
    public const string SicherungenUnterordner = "Sicherungen";

    /// <summary>
    /// Name des Ordners, den die Oberflaeche unter dem erkannten
    /// Synchronisierungsordner vorschlaegt. Ein Vorschlag, kein stilles Setzen
    /// (§1.3): Gewaehlt wird er mit einem Klick, nicht hinter dem Ruecken.
    /// </summary>
    public const string Vorschlagsname = "Kanzlei App Daten";

    /// <inheritdoc cref="Ermittle(AutomationDbContext, Func{string, string?})"/>
    public static string Ermittle(AutomationDbContext db) => Ermittle(db, AppOrdnerPfad.Umgebung);

    /// <summary>
    /// Der aufgeloeste App-Daten-Ordner — oder eine leere Zeichenkette, wenn
    /// keiner gesetzt ist oder er sich auf diesem Rechner nicht aufloesen
    /// laesst.
    /// </summary>
    public static string Ermittle(AutomationDbContext db, Func<string, string?> umgebung) =>
        Aufgeloest(db, satz => satz.AppDatenOrdner, umgebung);

    /// <inheritdoc cref="Abgeleitet(AutomationDbContext, string, Func{string, string?})"/>
    public static string Abgeleitet(AutomationDbContext db, string unterordner) =>
        Abgeleitet(db, unterordner, AppOrdnerPfad.Umgebung);

    /// <summary>
    /// Ein Unterordner unter dem App-Daten-Ordner — leer, wenn es keinen gibt.
    /// Angelegt wird hier nichts: Ordner entstehen beim ersten Schreiben, nicht
    /// beim Speichern der Einstellung.
    /// </summary>
    public static string Abgeleitet(
        AutomationDbContext db, string unterordner, Func<string, string?> umgebung)
    {
        var wurzel = Ermittle(db, umgebung);
        return wurzel.Length == 0 ? string.Empty : Path.Combine(wurzel, unterordner);
    }

    /// <summary>
    /// Der aufgeloeste Wert eines Ordnerfelds. Leer heisst „nicht gesetzt" — und
    /// ein relativ gespeicherter Ordner, dessen Anker auf diesem Rechner fehlt,
    /// zaehlt ausdruecklich genauso: Lieber der bekannte Rueckfall als ein
    /// stilles Aufloesen in einen fremden Baum.
    /// </summary>
    public static string Aufgeloest(
        AutomationDbContext db,
        Func<KanzleiSettingsEntity, string> feld,
        Func<string, string?> umgebung) =>
        AppOrdnerPfad.LoeseAuf(Gespeichert(db, feld), umgebung) ?? string.Empty;

    /// <summary>
    /// Die Speicherform eines Ordnerfelds, getrimmt — absolut oder
    /// <c>%Var%\Rest</c>. Fuer Aufrufer, die wissen muessen, was gespeichert
    /// <em>steht</em>, nicht was daraus wird.
    /// </summary>
    public static string Gespeichert(
        AutomationDbContext db, Func<KanzleiSettingsEntity, string> feld)
    {
        var satz = db.KanzleiSettings.AsNoTracking()
            .FirstOrDefault(eintrag => eintrag.Id == KanzleiSettingsEntity.SingletonId);
        return satz is null ? string.Empty : feld(satz).Trim();
    }
}
