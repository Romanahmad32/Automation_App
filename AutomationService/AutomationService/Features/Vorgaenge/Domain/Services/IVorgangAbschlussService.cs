using AutomationService.Features.Vorgaenge.Domain.Persistence;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Schließt einen Vorgang ab (§4.8): Status „versendet", Abschlusszeitpunkt
/// und das Hochzählen der laufenden Auftragsnummer (§7.1) passieren in
/// **einer** Transaktion — entweder beides oder nichts. Ersetzt die frühere
/// zweischrittige Variante im Frontend (Vorgang upserten, dann Nummer erhöhen),
/// bei der ein Teilfehler die Nummernvergabe aus dem Tritt brachte.
/// </summary>
public interface IVorgangAbschlussService
{
    /// <summary>
    /// Schließt den Vorgang zur Referenz ab. Null, wenn keiner passt; ein
    /// bereits abgeschlossener Vorgang wird unverändert zurückgegeben, ohne die
    /// Auftragsnummer erneut hochzuzählen (idempotent).
    /// </summary>
    Task<VorgangEntity?> AbschliessenAsync(string referenz, CancellationToken cancellationToken = default);
}
