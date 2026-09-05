namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Traegt die Vorzugsreihenfolge der OneDrive-Umgebungsvariablen (#103), gegen
/// die <see cref="AppOrdnerPfad.MacheRelativ(string?, Func{string, string?})"/>
/// beim Speichern eines neuen Pfades sucht.
///
/// Wichtig ist, was hier <em>nicht</em> geschieht: Die App spricht mit keiner
/// Cloud, meldet sich nirgends an und kennt kein Konto. Sie liest die
/// Umgebungsvariablen, die der Client selbst setzt, und rechnet mit ganz
/// gewoehnlichen Ordnerpfaden weiter; ob dahinter OneDrive, ein Netzlaufwerk
/// oder eine lokale Platte steht, ist ihr gleichgueltig.
///
/// Dieselbe Erkennung gibt es im Frontend (<c>SynchronisierterOrdner</c>), dort
/// aber nur, um dem Anwalt einen Ordner <em>vorzuschlagen</em>. Verbindlich ist
/// diese Fassung: Sie traegt die Speicherform der Pfade
/// (<see cref="AppOrdnerPfad"/>), und die entsteht im Backend — „das Frontend
/// rechnet nie um" (#33).
/// </summary>
public static class SynchronisierterWurzelOrdner
{
    /// <summary>
    /// Die Variablen in der Reihenfolge, in der sie zutreffen. Das
    /// Geschaeftskonto zuerst: Eine Kanzlei, die beides eingerichtet hat, meint
    /// mit „meinem OneDrive" das der Kanzlei.
    ///
    /// Die Reihenfolge gilt nur beim <em>Suchen</em>. Beim Aufloesen eines
    /// gespeicherten Pfades wird ausschliesslich der festgehaltene Anker
    /// benutzt — siehe <see cref="AppOrdnerPfad.LoeseAuf(string?)"/>.
    /// </summary>
    public static readonly IReadOnlyList<string> Variablen =
    [
        "OneDriveCommercial",
        "OneDriveConsumer",
        "OneDrive",
    ];
}
