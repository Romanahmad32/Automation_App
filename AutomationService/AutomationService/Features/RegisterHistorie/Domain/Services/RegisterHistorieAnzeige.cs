using System.Globalization;
using AutomationService.Features.RegisterHistorie.Domain.Persistence;

namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Wie eine historische Registerzeile lesbar wird: das Zeichen aus Nummer,
/// Jahr und Abteilung, und die Parteienspalte aus der Freitextzelle.
///
/// Liegt in der Domain der Registerhistorie und nicht bei den Vorgängen, obwohl
/// die Registeransicht sie braucht: Wie eine historische Zeile aussieht, weiß
/// dieser Slice, und die Zeilen der Ansicht (<c>RegisterZeilenBau</c>), die
/// Vorschau des Imports und der Bearbeiten-Dialog müssen alle dasselbe zeigen.
/// </summary>
public static class RegisterHistorieAnzeige
{
    /// <summary>
    /// Das Zeichen, wie es in der Kanzleidatei steht: "10/19-I C 02" wird zu
    /// "10/19-I C02" — zweistellige Nummer, zweistelliges Jahr, Zusatz direkt
    /// dahinter, dann die Abteilung. Ohne Abteilung entfiele sonst nur das
    /// Leerzeichen am Ende, deshalb das abschließende Trimmen.
    /// </summary>
    public static string Zeichen(RegisterHistorieEntity zeile)
    {
        ArgumentNullException.ThrowIfNull(zeile);
        var nummer = zeile.LaufendeNummer.ToString("00", CultureInfo.InvariantCulture);
        var jahr = (((zeile.Jahr % 100) + 100) % 100).ToString("00", CultureInfo.InvariantCulture);
        return $"{nummer}/{jahr}{zeile.NummerZusatz.Trim()} {zeile.Abteilung.Trim()}".Trim();
    }

    /// <summary>
    /// Die Parteienspalte. Der Bestand kennt zwei Formen, und beide sollen
    /// gleich aussehen wie am Bildschirm:
    /// Form A "Mandant ./. Gegner" (Zivilsache), Form B "Sachart Mandant"
    /// (Bußgeld-, Straf-, Familiensache — dort gibt es keine Gegenseite).
    /// </summary>
    public static string Parteien(string? mandant, string? gegner, string? sachart)
    {
        var name = (mandant ?? string.Empty).Trim();
        var gegenseite = (gegner ?? string.Empty).Trim();
        if (gegenseite.Length > 0) return $"{name} ./. {gegenseite}".Trim();

        var art = (sachart ?? string.Empty).Trim();
        return art.Length > 0 ? $"{art} {name}".Trim() : name;
    }

    /// <summary>
    /// Die Sachbestandsspalte: Sachbestand und Datum, wie sie in der
    /// Freitextzelle nebeneinanderstanden ("Unfall v. 28.12.17"). Getrennt
    /// gespeichert, weil nur so nach Datum gefiltert werden kann; wieder
    /// zusammengesetzt, weil die Spalte im Register einen Satz zeigt.
    /// </summary>
    public static string Sachbestand(RegisterHistorieEntity zeile)
    {
        ArgumentNullException.ThrowIfNull(zeile);
        var was = zeile.Sachbestand.Trim();
        var wann = zeile.Unfalldatum.Trim();
        if (wann.Length == 0) return was;
        return was.Length == 0 ? $"v. {wann}" : $"{was} v. {wann}";
    }
}
