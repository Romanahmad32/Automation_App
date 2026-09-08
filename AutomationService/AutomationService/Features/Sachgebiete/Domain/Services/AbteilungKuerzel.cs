namespace AutomationService.Features.Sachgebiete.Domain.Services;

/// <summary>
/// Regeln für Abteilungskürzel und Überschneidungen (§7.1) — das C#-Gegenstück
/// zu <c>abteilung_kuerzel.dart</c> im Frontend.
///
/// Eine Abteilung ist ein Hauptsachgebiet mit optionalem Nebenbezug,
/// geschrieben als <c>Hauptkürzel/Nebenteil</c> (<c>C05/3</c> = Strafrecht mit
/// Verkehrsbezug). Der Nebenteil ist das Kürzel des Nebensachgebiets ohne das
/// Präfix <c>C0</c> (<c>C03</c> → <c>3</c>, <c>C03o</c> → <c>3o</c>); die
/// Rückabbildung setzt <c>C0</c> wieder davor.
///
/// Kürzel werden ohne Leerzeichen geführt: Das Referenzformat (§4.2) trennt die
/// Abteilung am Leerzeichen — ein Kürzel wie <c>C 03o</c> zerfiele in der
/// Zerlegung auf beiden Seiten still. Deshalb <see cref="Normalisiere"/> beim
/// Einlesen; der gewachsene Registerbestand schreibt dasselbe Kürzel mal mit
/// und mal ohne Leerzeichen.
///
/// Beide Seiten müssen dieselbe Antwort geben: Ein Kürzel, das hier anders
/// zerfällt als im Frontend, ordnet dieselbe Zeile zwei Sachgebieten zu.
/// </summary>
public static class AbteilungKuerzel
{
    const string Praefix = "C0";

    /// <summary>Entfernt sämtliche Leerzeichen (<c>C 03o</c> → <c>C03o</c>).</summary>
    public static string Normalisiere(string? abteilung) =>
        string.Concat((abteilung ?? string.Empty).Where(zeichen => !char.IsWhiteSpace(zeichen)));

    /// <summary>
    /// Zerlegt eine gespeicherte Abteilung in Haupt- und Nebenkürzel
    /// (<c>C05/3</c> → <c>C05</c> + <c>C03</c>). Ohne Schrägstrich ist alles
    /// Hauptkürzel, der Nebenteil bleibt <c>null</c>.
    /// </summary>
    public static (string Haupt, string? Neben) Zerlege(string? abteilung)
    {
        var bereinigt = Normalisiere(abteilung);
        var trenner = bereinigt.IndexOf('/');
        if (trenner < 0) return (bereinigt, null);

        var nebenRoh = bereinigt[(trenner + 1)..];
        return (bereinigt[..trenner], nebenRoh.Length == 0 ? null : Praefix + nebenRoh);
    }
}
