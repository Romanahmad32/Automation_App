using System.Text.RegularExpressions;

namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

/// <summary>
/// Ob zwei Kennzeichen dasselbe Fahrzeug benennen — beim Vergleichen zählt die
/// Schreibweise nicht (§4.2). Umgeschrieben wird hier nichts: Die Lesarten
/// dienen allein dem Vergleich; was gespeichert, angezeigt und ins Schreiben
/// übernommen wird, bleibt, wie es eingegeben wurde.
///
/// <para>
/// <b>Das C#-Gegenstück zu <c>gleichesKennzeichen</c> und
/// <c>kennzeichenLesarten</c></b>
/// (<c>lib/core/general_classes/kennzeichen_normalisierung.dart</c>). Beide
/// Seiten beantworten dieselbe Frage — gehört diese Zentralruf-Antwort zu
/// diesem Vorgang? —, das Backend für die vermutete Zuordnung im Postfach, das
/// Frontend für die Auswahlhilfe. Bis #144 rechneten sie verschieden: Das
/// Backend teilte ein mehrdeutiges <c>HGE1427</c> geraten als <c>HG-E 1427</c>
/// auf und fand deshalb den Vorgang <c>H-GE 1427</c> nicht, den das Frontend
/// fand. Beide Seiten prüfen ihre Regel deshalb gegen dieselbe Falltabelle,
/// <c>docs/kennzeichen_faelle.json</c>.
/// </para>
/// </summary>
public static partial class KennzeichenVergleich
{
    /// <summary>
    /// Mit Trennzeichen zwischen Unterscheidungszeichen und Erkennungsbuchstaben:
    /// Die Aufteilung ist gesagt (<c>HG-E 1427</c>, <c>HG E1427</c>). Ziffern als
    /// <c>[0-9]</c>, weil .NETs <c>\d</c> auch fremde Ziffernzeichen nimmt, Darts
    /// nicht — und beide Seiten sollen dasselbe lesen.
    /// </summary>
    [GeneratedRegex(@"^([A-ZÄÖÜ]{1,3})[ \-]([A-ZÄÖÜ]{1,2})[ \-]?([0-9]{1,4})\s*([HE])?$")]
    private static partial Regex MitTrennerRegex();

    /// <summary>
    /// Alle Buchstaben in einem Block (<c>HGE1427</c>, <c>HGE 1427</c>) — wo er zu
    /// teilen ist, sagt das Muster nicht; das rechnet <see cref="Lesarten"/> aus.
    /// </summary>
    [GeneratedRegex(@"^([A-ZÄÖÜ]{2,5})[ \-]?([0-9]{1,4})\s*([HE])?$")]
    private static partial Regex OhneTrennerRegex();

    [GeneratedRegex(@"\s+")]
    private static partial Regex LeerraumRegex();

    /// <summary>
    /// True, wenn beide Werte vorhanden sind und dasselbe Fahrzeug benennen:
    /// gleich bis auf Groß-/Kleinschreibung und Leerraum — das gilt auch für
    /// Werte, die kein Kfz-Kennzeichen sind (<c>123 abc</c> und <c>123 ABC</c>) —,
    /// oder ihre Lesarten treffen sich (<c>HGE1427</c> und <c>H-GE 1427</c>).
    /// Trennzeichen bleiben dabei bedeutsam: Wer sie für den Vergleich streicht,
    /// macht <c>HG-E 1427</c> und <c>H-GE 1427</c> zu einem Wagen.
    /// </summary>
    public static bool Gleich(string? a, string? b)
    {
        if (string.IsNullOrWhiteSpace(a) || string.IsNullOrWhiteSpace(b))
        {
            return false;
        }

        if (string.Equals(Bereinige(a), Bereinige(b), StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return Lesarten(a).Intersect(Lesarten(b)).Any();
    }

    /// <summary>
    /// Alle Lesarten eines Kfz-Kennzeichens in der Schreibweise mit Bindestrich,
    /// langes Unterscheidungszeichen zuerst — leer, wenn der Wert keines ist
    /// (Versicherungs-, Behörden-, Kurzzeit-, Auslandskennzeichen). Mit
    /// Trennzeichen gibt es genau eine, ohne bei drei und vier Buchstaben zwei:
    /// <c>HGE1427</c> ist <c>HG-E 1427</c> oder <c>H-GE 1427</c>.
    /// </summary>
    public static IReadOnlyList<string> Lesarten(string? wert)
    {
        if (string.IsNullOrWhiteSpace(wert))
        {
            return [];
        }

        var bereinigt = Bereinige(wert).ToUpperInvariant();
        var eindeutig = MitTrennerRegex().Match(bereinigt);
        if (eindeutig.Success)
        {
            var gruppe = eindeutig.Groups;
            return [$"{gruppe[1].Value}-{gruppe[2].Value} {gruppe[3].Value}{gruppe[4].Value}"];
        }

        var zusammen = OhneTrennerRegex().Match(bereinigt);
        if (!zusammen.Success)
        {
            return [];
        }

        var buchstaben = zusammen.Groups[1].Value;
        var nummer = zusammen.Groups[2].Value + zusammen.Groups[3].Value;

        // Vorn 1–3 Buchstaben, hinten 1–2 — beides zugleich erfüllbar nur in
        // diesem Fenster; bei 2 und bei 5 Buchstaben schrumpft es auf einen Wert.
        var laengstesVorn = Math.Min(buchstaben.Length - 1, 3);
        var kuerzestesVorn = Math.Max(buchstaben.Length - 2, 1);
        var lesarten = new List<string>();
        for (var vorn = laengstesVorn; vorn >= kuerzestesVorn; vorn--)
        {
            lesarten.Add($"{buchstaben[..vorn]}-{buchstaben[vorn..]} {nummer}");
        }

        return lesarten;
    }

    static string Bereinige(string wert) => LeerraumRegex().Replace(wert, " ").Trim();
}
