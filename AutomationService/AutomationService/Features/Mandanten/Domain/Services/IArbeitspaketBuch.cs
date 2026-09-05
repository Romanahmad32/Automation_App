using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Führt Buch über die Arbeitspakete des Mandanten-Imports (§5.1/§6.1): welches
/// Paket wann geholt und wann eingelesen wurde. Ohne dieses Buch merkt sich der
/// Erzeuger der Importdatei selbst, wo er aufgehört hat — und niemand kann
/// prüfen, ob Paket 3 fehlt, bevor Paket 4 geholt wird.
///
/// Den Ordnerbestand auf der Platte kennt das Backend <b>nicht</b>: der Scan
/// des Akten-Stammordners liegt im Frontend. Hier liegen die Zustände
/// (zugeordnet, vermerkt), deshalb wird der Bestand zugeschickt und aus beidem
/// zusammen entsteht, was offen ist. Das ist der Zuschnitt und keine Notlösung.
/// </summary>
public interface IArbeitspaketBuch
{
    /// <summary>
    /// Wählt die nächsten <paramref name="anzahl"/> offenen Ordner aus dem
    /// übergebenen Bestand, schreibt das Paket ins Buch und gibt es zurück.
    /// </summary>
    /// <exception cref="KeineOffenenOrdnerException">
    /// Kein Ordner des Bestands ist mehr offen. Dann wird nichts gebucht und
    /// keine Nummer vergeben — ein leeres Paket wäre eine Lücke, die keine ist.
    /// </exception>
    Task<ArbeitspaketEntity> HoleAsync(
        IReadOnlyList<string> ordnernamen,
        int anzahl,
        CancellationToken cancellationToken = default);

    /// <summary>Alle Pakete, neuestes zuerst.</summary>
    Task<IReadOnlyList<ArbeitspaketEntity>> GetAllAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Trägt nach, wie weit die Pakete abgearbeitet sind.
    /// <paramref name="erledigteOrdner"/> ist die vollständige Menge der Ordner,
    /// die aktuell zugeordnet oder vermerkt sind (nicht die Änderung) — dadurch
    /// ist die Rechnung wiederholbar statt aufaddiert.
    /// </summary>
    Task MarkiereEingelesenAsync(
        IReadOnlySet<string> erledigteOrdner,
        CancellationToken cancellationToken = default);
}
