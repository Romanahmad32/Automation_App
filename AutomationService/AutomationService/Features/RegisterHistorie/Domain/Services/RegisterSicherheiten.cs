namespace AutomationService.Features.RegisterHistorie.Domain.Services;

/// <summary>
/// Wie sicher der Erzeuger der Importdatei sich seiner Zerlegung war (§6.2).
/// Als Zeichenkette statt als Enum, weil der Dienst Enums als Zahlen
/// serialisiert — eine Zahl im Vertrag wäre für die Dart-Seite eine stumme
/// Kopplung an die Deklarationsreihenfolge.
///
/// Die Stufen sind die aus der Anleitung an den Erzeuger: <c>hoch</c> für eine
/// vollständige Form A, <c>mittel</c> für Form B, fehlende Abteilung oder einen
/// Sachbestand ohne Datum, <c>niedrig</c> für Nummernzusatz, mehrere Mandanten
/// in einer Zelle, Abteilung mit Schrägstrich und erkennbare Tippfehler.
/// </summary>
public static class RegisterSicherheiten
{
    public const string Hoch = "hoch";
    public const string Mittel = "mittel";
    public const string Niedrig = "niedrig";

    /// <summary>
    /// Der Erzeuger hat sich nicht geäußert. Eigener Wert und nicht
    /// stillschweigend <c>niedrig</c>: „nicht eingeschätzt" ist etwas anderes
    /// als „eingeschätzt und unsicher", und nur das erste ist ein Mangel der
    /// Datei. Zur Prüfliste zählt es trotzdem.
    /// </summary>
    public const string OhneAngabe = "ohneAngabe";

    /// <summary>
    /// Bringt den Wert aus der Datei auf eine der vier Stufen. Alles, was keine
    /// davon ist — leer, „sicher", ein Tippfehler —, wird zu
    /// <see cref="OhneAngabe"/>, statt als unbekannte Stufe weitergereicht zu
    /// werden: Die Oberfläche filtert danach, und ein Wert, den kein Filter
    /// kennt, versteckt die Zeile.
    /// </summary>
    public static string Normalisiere(string? wert) => (wert ?? string.Empty).Trim().ToLowerInvariant() switch
    {
        Hoch => Hoch,
        Mittel => Mittel,
        Niedrig => Niedrig,
        _ => OhneAngabe,
    };
}
