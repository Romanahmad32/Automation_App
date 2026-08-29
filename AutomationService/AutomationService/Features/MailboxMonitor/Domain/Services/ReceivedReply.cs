using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Eine vom Postfach-Monitor erfasste und geparste Zentralruf-Antwort, wie der
/// Store (<see cref="IReceivedReplyStore"/>) sie liefert. Die Treffer werden in
/// der SQLite-Datenbank gehalten (überdauern den Neustart); die Oberfläche ruft
/// sie ab und quittiert sie. Best-effort wird die Antwort über die Referenz mit
/// einem Vorgang verknüpft — das Übernehmen bleibt der bestätigte Frontend-Schritt.
/// </summary>
public sealed record ReceivedReply
{
    /// <summary>Stabile, URL-sichere ID für Abruf und Quittung über die API.</summary>
    public required string Id { get; init; }

    /// <summary>Zeitpunkt der Erfassung durch den Monitor.</summary>
    public required DateTimeOffset ReceivedAt { get; init; }

    public required string? Subject { get; init; }

    public required string? From { get; init; }

    /// <summary>Die aus der Mail extrahierten Antwortdaten (via gemeinsamem Parser).</summary>
    public required ZentralrufReplyData Data { get; init; }

    /// <summary>Hinweise auf mögliche Falschzuordnungen, die der Anwalt prüfen sollte.</summary>
    public required IReadOnlyList<string> Warnings { get; init; }

    /// <summary>
    /// Der aus der Mail gewonnene Rohtext, der durch den Parser lief. Dient der
    /// Oberfläche als Original-Ansicht/Fallback, falls das automatische Mapping
    /// unvollständig ist und der Anwalt von Hand korrigieren oder neu auswerten will.
    /// </summary>
    public string? RawText { get; init; }

    /// <summary>
    /// Vollständige Pfade der Dateien, die an der Antwort hingen (§4.3). Der
    /// Versand bietet sie zum Anhängen an (§4.7); leer, wenn nichts dranhing.
    /// </summary>
    public IReadOnlyList<string> AnhangPfade { get; init; } = [];

    /// <summary>Vom Nutzer als gesehen/übernommen markiert.</summary>
    public bool Acknowledged { get; init; }

    /// <summary>
    /// True, wenn die Verknüpfung zum Vorgang nicht über die Referenz, sondern
    /// über den Fallback (Gegner-Kennzeichen + Unfalldatum) vermutet wurde —
    /// vom Anwalt noch zu bestätigen.
    /// </summary>
    public bool ZuordnungVermutet { get; init; }
}
