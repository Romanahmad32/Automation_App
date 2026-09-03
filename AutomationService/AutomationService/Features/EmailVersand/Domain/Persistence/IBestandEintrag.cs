namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Was die drei Mail-Bestände gemeinsam haben (§4.7): Vorlagen, Grußformeln
/// und Anredeanfänge sind je eine vom Anwalt gepflegte Liste mit einer
/// laufenden Nummer.
///
/// Die Schnittstelle trägt keine Fachlichkeit — sie ist nur der Griff, an dem
/// <see cref="Services.BestandVergabe"/> die Nummer vergeben und eine Dublette
/// erkennen kann, ohne dreimal dieselbe Abfrage zu enthalten.
/// </summary>
public interface IBestandEintrag
{
    /// <summary>Laufende Nummer; 0 heißt „noch nicht vergeben".</summary>
    int Id { get; set; }
}

/// <summary>
/// Ein Bestandseintrag, dessen Reihenfolge der Anwalt bestimmt — die Auswahl
/// beim Verfassen zeigt ihn in genau dieser.
/// </summary>
public interface IBestandEintragMitReihenfolge : IBestandEintrag
{
    /// <summary>
    /// Reihenfolge in der Auswahl. Zehnerschritte, damit sich später etwas
    /// dazwischen einsortieren lässt; 0 heißt „ans Ende".
    /// </summary>
    int Sortierung { get; set; }
}
