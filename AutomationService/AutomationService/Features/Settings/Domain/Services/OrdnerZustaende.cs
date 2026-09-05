using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Ermittelt die Lage aller fuenf Ordnerfelder (#103) — die Auskunft hinter
/// <c>GET api/Settings/ordner</c>.
///
/// Die Reihenfolge ist Teil des Vertrags und nicht Zufall: erst der eine
/// Ordner, aus dem die uebrigen fallen, dann der Akten-Stammordner als zweite
/// eigene Wahl, dann die drei, die im Normalfall gar nicht mehr eingestellt
/// werden.
/// </summary>
public static class OrdnerZustaende
{
    public const string FeldAppDatenOrdner = "appDatenOrdner";
    public const string FeldAktenStammordner = "aktenStammordner";
    public const string FeldVorlagenOrdner = "vorlagenOrdner";
    public const string FeldRegisterAblageOrdner = "registerAblageOrdner";
    public const string FeldSicherungsAblageOrdner = "sicherungsAblageOrdner";

    /// <inheritdoc cref="Ermittle(AutomationDbContext, Func{string, string?}, Func{string, bool})"/>
    public static IReadOnlyList<OrdnerZustand> Ermittle(AutomationDbContext db) =>
        Ermittle(db, AppOrdnerPfad.Umgebung, Directory.Exists);

    /// <summary>
    /// Die fuenf Zustaende in der vertraglich festgelegten Reihenfolge.
    ///
    /// <paramref name="existiert"/> ist die einzige IO dieser Klasse und
    /// deshalb injizierbar: Ein Test, der echte Ordner anlegen muesste, um eine
    /// Fallunterscheidung zu pruefen, prueft am Ende das Dateisystem.
    /// </summary>
    public static IReadOnlyList<OrdnerZustand> Ermittle(
        AutomationDbContext db,
        Func<string, string?> umgebung,
        Func<string, bool> existiert)
    {
        var satz = db.KanzleiSettings.AsNoTracking()
            .FirstOrDefault(eintrag => eintrag.Id == KanzleiSettingsEntity.SingletonId)
            ?? new KanzleiSettingsEntity();

        var appDaten = AppDatenOrdnerVorgabe.Ermittle(db, umgebung);
        var abgeleitetOderNicht = appDaten.Length > 0
            ? OrdnerZustandArten.Abgeleitet
            : OrdnerZustandArten.NichtGesetzt;

        return
        [
            Baue(FeldAppDatenOrdner, satz.AppDatenOrdner, appDaten,
                OrdnerZustandArten.NichtGesetzt, umgebung, existiert),

            // Der Akten-Stammordner wird nirgends abgeleitet: Er zeigt auf die
            // gewachsene Ablage der Kanzlei, nicht auf etwas, das die App anlegt.
            Baue(FeldAktenStammordner, satz.AktenStammordner,
                AppOrdnerPfad.LoeseAuf(satz.AktenStammordner, umgebung) ?? string.Empty,
                OrdnerZustandArten.NichtGesetzt, umgebung, existiert),

            Baue(FeldVorlagenOrdner, satz.VorlagenOrdner,
                VorlagenOrdnerVorgabe.Ermittle(db, umgebung),
                appDaten.Length > 0 ? OrdnerZustandArten.Abgeleitet : OrdnerZustandArten.Standard,
                umgebung, existiert),

            Baue(FeldRegisterAblageOrdner, satz.RegisterAblageOrdner,
                RegisterAblageVorgabe.Ermittle(db, umgebung),
                abgeleitetOderNicht, umgebung, existiert),

            Baue(FeldSicherungsAblageOrdner, satz.SicherungsAblageOrdner,
                SicherungsAblageVorgabe.Ermittle(db, umgebung),
                abgeleitetOderNicht, umgebung, existiert),
        ];
    }

    /// <summary>
    /// Ein Zustand. <paramref name="leerZustand"/> sagt, was ein leeres Feld
    /// bedeutet — das ist die einzige Stelle, an der sich die fuenf Felder
    /// unterscheiden.
    /// </summary>
    static OrdnerZustand Baue(
        string feld,
        string rohGespeichert,
        string wirksam,
        string leerZustand,
        Func<string, string?> umgebung,
        Func<string, bool> existiert)
    {
        var gespeichert = rohGespeichert.Trim();
        if (gespeichert.Length == 0)
        {
            return new OrdnerZustand(feld, string.Empty, wirksam, leerZustand, string.Empty);
        }

        var aufgeloest = AppOrdnerPfad.LoeseAuf(gespeichert, umgebung);
        var zustand = aufgeloest is null
            ? OrdnerZustandArten.AnkerFehlt
            : existiert(aufgeloest) ? OrdnerZustandArten.Bereit : OrdnerZustandArten.OrdnerFehlt;

        return new OrdnerZustand(
            feld, gespeichert, wirksam, zustand, AppOrdnerPfad.Anker(gespeichert) ?? string.Empty);
    }
}
