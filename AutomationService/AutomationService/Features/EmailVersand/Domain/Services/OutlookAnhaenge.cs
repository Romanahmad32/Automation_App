using System.Runtime.InteropServices;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Was beim Griff nach Outlook herauskam (§4.7) — nicht nur die Dateien,
/// sondern auch, <b>woher</b> sie stammen.
///
/// Der Griff ist von aussen nicht nachvollziehbar: Er liest die Nachricht, die
/// in Outlook gerade offen ist, sonst die in der Liste markierte. Welche das
/// war, weiss nur Outlook — und ohne diese Angabe sieht ein Griff in die
/// falsche Nachricht genauso aus wie ein richtiger. Deshalb gehen Betreff und
/// Absender mit zurueck: Die Oberflaeche kann dann sagen, aus welcher Mail die
/// Vorschlaege kommen, statt sie wortlos hinzulegen.
/// </summary>
/// <param name="Pfade">Die abgelegten Anhaenge mit vollem Pfad.</param>
/// <param name="Betreff">Betreff der gelesenen Nachricht; leer, wenn keine da war.</param>
/// <param name="Absender">Anzeigename des Absenders; leer, wenn nicht lesbar.</param>
/// <param name="AusOffenemFenster">
/// True, wenn die Nachricht in einem eigenen Fenster offen stand; false, wenn
/// sie nur in der Liste markiert war. Genau diese Regel erklaert dem Anwalt,
/// warum er die Anhaenge einer anderen Mail bekommen hat als erwartet.
/// </param>
/// <param name="OutlookErreicht">
/// False, wenn Outlook ueberhaupt nicht geantwortet hat — nicht installiert,
/// nicht gestartet, oder der Zugriff lief in die Zeitgrenze. Von "nichts
/// ausgewaehlt" zu unterscheiden, weil beides sonst als dieselbe leere Liste
/// ankaeme und der Anwalt am falschen Ende suchte.
/// </param>
public sealed record OutlookAnhaenge(
    IReadOnlyList<string> Pfade,
    string Betreff,
    string Absender,
    bool AusOffenemFenster,
    bool OutlookErreicht)
{
    /// <summary>Outlook hat geantwortet, aber es war nichts ausgewaehlt.</summary>
    public static readonly OutlookAnhaenge Keine =
        new([], string.Empty, string.Empty, false, true);

    /// <summary>Outlook war nicht zu sprechen.</summary>
    public static readonly OutlookAnhaenge Unerreichbar =
        new([], string.Empty, string.Empty, false, false);

    /// <summary>
    /// Liest Betreff und Absender von der gelesenen Nachricht. Beides ist
    /// Beiwerk: Faellt es aus, sind die Anhaenge trotzdem geholt, und ein
    /// leerer Betreff ist besser als ein Abbruch.
    /// </summary>
    public static OutlookAnhaenge Von(
        dynamic nachricht,
        IReadOnlyList<string> pfade,
        bool ausOffenemFenster) =>
        new(pfade, Text(() => nachricht.Subject), Text(() => nachricht.SenderName), ausOffenemFenster, true);

    private static string Text(Func<object?> lies)
    {
        try
        {
            return lies() as string ?? string.Empty;
        }
        catch (COMException)
        {
            return string.Empty;
        }
    }
}
