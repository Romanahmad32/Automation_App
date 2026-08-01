using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Speicher der vom Monitor erfassten Zentralruf-Antworten. Persistiert in der
/// SQLite-Datenbank — die Treffer überdauern damit einen Neustart und müssen
/// nicht erneut eingelesen werden. Dedupliziert über einen stabilen Mail-
/// Schlüssel (Message-Id bzw. UID), damit dieselbe Nachricht beim Reconnect-
/// Nachscannen nicht doppelt erscheint.
/// </summary>
public interface IReceivedReplyStore
{
    /// <summary>True, wenn zu diesem Mail-Schlüssel bereits ein Treffer vorliegt.</summary>
    Task<bool> ContainsAsync(string dedupeKey, CancellationToken cancellationToken = default);

    /// <summary>
    /// Legt einen Treffer an, sofern der Schlüssel neu ist, und gibt ihn zurück;
    /// bei bereits bekanntem Schlüssel <c>null</c>. Sucht best-effort den Vorgang
    /// zur Referenz und vermerkt ihn als Vorschlag (<c>VorgangId</c>/<c>Zugeordnet</c>),
    /// ohne den Vorgang selbst zu verändern.
    /// </summary>
    Task<ReceivedReply?> AddAsync(
        string dedupeKey,
        ZentralrufReplyData data,
        string? subject,
        string? from,
        IReadOnlyList<string> warnings,
        string? rawText = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ReceivedReply>> GetAllAsync(bool includeAcknowledged, CancellationToken cancellationToken = default);

    /// <summary>Markiert einen Treffer als gesehen/übernommen. False, wenn die ID unbekannt ist.</summary>
    Task<bool> AcknowledgeAsync(string id, CancellationToken cancellationToken = default);

    /// <summary>Gesamtzahl der erfassten Treffer (inklusive quittierter).</summary>
    Task<int> CountAsync(CancellationToken cancellationToken = default);
}
