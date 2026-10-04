namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>Wie die Seitenvorschau ausgegangen ist.</summary>
public enum VollmachtVorschauArt
{
    /// <summary>Die Seite liegt als PDF bei.</summary>
    Erstellt,

    /// <summary>Die Vorlage dieser Art liegt nicht im Vorlagenordner.</summary>
    VorlageFehlt,

    /// <summary>Ausfüllen oder Umwandeln gescheitert — drucken bleibt möglich.</summary>
    Fehler,
}

/// <summary>
/// Die ausgefüllte Vollmacht als Seite, wie sie gedruckt würde (§4.11). Ein
/// Wert wie <see cref="VollmachtErgebnis"/>, kein HTTP-Fehler: Eine fehlende
/// Vorlage oder eine Vorschau ohne Word sind vorgesehene Ausgänge, die der
/// Dialog neben den Feldern zeigt.
/// </summary>
/// <param name="Art">Der Ausgang.</param>
/// <param name="Pdf">Die Seite, nur bei <see cref="VollmachtVorschauArt.Erstellt"/>.</param>
/// <param name="Meldung">Klartext für den Anwalt bei allem anderen.</param>
/// <param name="Warnungen">Platzhalter, die in der Vorlage stehen geblieben sind (§4.4).</param>
public sealed record VollmachtVorschau(
    VollmachtVorschauArt Art,
    byte[]? Pdf,
    string? Meldung,
    IReadOnlyList<string> Warnungen);
