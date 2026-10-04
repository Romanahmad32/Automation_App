namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>Wie ein Druck- oder Öffnen-Auftrag ausgegangen ist.</summary>
public enum VollmachtErgebnisArt
{
    /// <summary>An den Drucker übergeben; die Arbeitsdatei ist wieder gelöscht.</summary>
    Gedruckt,

    /// <summary>Ausgefüllt, aber nicht gedruckt — die Datei liegt zum Öffnen bereit.</summary>
    DruckFehlgeschlagen,

    /// <summary>Ausgefüllt und bewusst nicht gedruckt („In Word öffnen").</summary>
    Ausgefuellt,

    /// <summary>Die Vorlage dieser Art liegt nicht im Vorlagenordner.</summary>
    VorlageFehlt,

    /// <summary>Ausfüllen gescheitert, etwa weil die Arbeitsdatei noch in Word offen ist.</summary>
    Fehler,
}

/// <summary>
/// Ergebnis eines Vollmacht-Auftrags. Kein Fehlerstatus über HTTP, sondern ein
/// Wert: „Druck fehlgeschlagen" ist ein vorgesehener Ausgang, auf den das
/// Frontend mit dem Öffnen der Datei antwortet — dafür braucht es den
/// <see cref="Pfad"/>.
/// </summary>
/// <param name="Art">Der Ausgang.</param>
/// <param name="Pfad">Die ausgefüllte Datei, sofern sie (noch) da ist; sonst null.</param>
/// <param name="Meldung">Klartext für den Anwalt bei allem außer <see cref="VollmachtErgebnisArt.Gedruckt"/>.</param>
/// <param name="Warnungen">Platzhalter, die in der Vorlage stehen geblieben sind (§4.4).</param>
/// <param name="Drucker">Bei <see cref="VollmachtErgebnisArt.Gedruckt"/>: an welchen Drucker Word übergeben hat.</param>
public sealed record VollmachtErgebnis(
    VollmachtErgebnisArt Art,
    string? Pfad,
    string? Meldung,
    IReadOnlyList<string> Warnungen,
    string? Drucker = null);
