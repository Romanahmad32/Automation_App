using System.Globalization;
using AutomationService.Features.RegisterHistorie.Domain.Persistence;
using AutomationService.Features.RegisterHistorie.Domain.Services;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Macht aus einer übernommenen Zeile des gewachsenen Kanzleiregisters (§6.2)
/// eine Zeile im Spaltenschema des Registers.
///
/// Eigene Datei und nicht in <see cref="RegisterZeilenBau"/>: Dort steht, wie
/// aus einem <em>Vorgang</em> eine Zeile wird, hier, wie aus einer
/// <em>historischen</em> — zwei verschiedene Quellen mit verschiedenen
/// Eigenheiten, die nur die Sortierung teilen.
///
/// Die Kante zeigt in eine Richtung: Die Vorgänge kennen die Registerhistorie,
/// die Registerhistorie kennt die Vorgänge nicht. Andersherum müsste der
/// Import wissen, was ein Vorgang ist — und ein historischer Eintrag ist
/// gerade keiner.
/// </summary>
public static class RegisterHistorieZeilen
{
    /// <summary>
    /// Historische Zeilen gelten immer als abgeschlossen: Sie stammen aus dem
    /// Register der erledigten Jahre. Der Dateifilter „nur abgeschlossene"
    /// lässt sie deshalb sämtlich durch — was auch heißt, dass er sie nie
    /// aussortiert.
    /// </summary>
    public static RegisterZeile Zeile(RegisterHistorieEntity zeile)
    {
        ArgumentNullException.ThrowIfNull(zeile);
        return new RegisterZeile(
            Jahr: zeile.Jahr.ToString(CultureInfo.InvariantCulture),
            LaufendeNummer: zeile.LaufendeNummer,
            Zeichen: RegisterHistorieAnzeige.Zeichen(zeile),
            Parteien: RegisterHistorieAnzeige.Parteien(zeile.Mandant, zeile.Gegner, zeile.Sachart),
            Sachbestand: RegisterHistorieAnzeige.Sachbestand(zeile),
            Rechtsgebiet: RechtsgebietAnzeige.Fuer(zeile.Rechtsgebiet),
            Abgeschlossen: true,
            Quelle: RegisterQuellen.Historie,
            HistorieId: zeile.Id,
            VorgangReferenz: null,
            Sicherheit: RegisterSicherheiten.Normalisiere(zeile.Sicherheit),
            Befunde: RegisterHistorieListen.Lies(zeile.BefundeJson));
    }
}
