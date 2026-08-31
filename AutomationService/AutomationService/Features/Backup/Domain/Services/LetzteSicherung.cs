namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Wie der letzte automatische Sicherungslauf ausgegangen ist (§7.2, #39).
///
/// Der Lauf passiert, wenn das Fenster schon zu ist — es gibt in dem Moment
/// niemanden mehr, dem man etwas sagen könnte. Deshalb wird das Ergebnis
/// aufgehoben und beim <em>nächsten</em> Start gezeigt. Ohne das wäre eine
/// Sicherung, die seit Wochen an einem umbenannten Ordner scheitert, für den
/// Anwalt nicht von einer heilen zu unterscheiden — bis er sie braucht.
/// </summary>
/// <param name="Zeitpunkt">Wann der Lauf stattfand.</param>
/// <param name="Gelungen">Ob am Ende ein Archiv im Ablageordner lag.</param>
/// <param name="Datei">Name des Archivs, wenn der Lauf gelungen ist.</param>
/// <param name="Meldung">
/// Was schiefging, in Worten, die der Anwalt lesen kann — kein Stacktrace.
/// </param>
/// <param name="FehlerQuittiert">
/// Ob die Meldung schon einmal gezeigt und weggeklickt wurde. Sonst stünde sie
/// bei jedem Start wieder da, auch wenn der Anwalt sie längst verstanden hat.
/// Ein gelungener Lauf setzt den Merker ohnehin zurück.
/// </param>
public sealed record LetzteSicherung(
    DateTime Zeitpunkt,
    bool Gelungen,
    string? Datei,
    string? Meldung,
    bool FehlerQuittiert)
{
    /// <summary>Ein Fehlschlag, der dem Anwalt noch gezeigt werden muss.</summary>
    public bool OffenerFehler => !Gelungen && !FehlerQuittiert;
}
