using System.Globalization;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Der Anzeigename eines Rechtsgebiets für die vierte Registerspalte.
///
/// Das Backend speichert das Rechtsgebiet als den stabilen Schlüssel des
/// Flutter-Enums ("verkehrsstrafrecht"). Die Anzeige leitet sich daraus ab,
/// statt eine zweite Liste zu führen: Jeder Wert des Enums ist ein einzelnes
/// zusammengeschriebenes Wort, dessen Anzeigename sich nur im ersten Buchstaben
/// unterscheidet. Damit kann ein neues Rechtsgebiet im Frontend nicht dazu
/// führen, dass hier eine Übersetzung fehlt — der häufigste Weg, auf dem so
/// eine Doppelliste auseinanderläuft.
/// </summary>
public static class RechtsgebietAnzeige
{
    /// <summary>Platzhalter, wenn am Vorgang kein Rechtsgebiet steht.</summary>
    public const string Unbekannt = "—";

    public static string Fuer(string? wert)
    {
        var roh = (wert ?? string.Empty).Trim();
        if (roh.Length == 0) return Unbekannt;
        return string.Concat(
            roh[..1].ToUpper(CultureInfo.GetCultureInfo("de-DE")),
            roh[1..]);
    }
}
