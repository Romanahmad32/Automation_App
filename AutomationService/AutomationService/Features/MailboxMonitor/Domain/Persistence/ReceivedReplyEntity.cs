namespace AutomationService.Features.MailboxMonitor.Domain.Persistence;

/// <summary>
/// Persistenz-Abbild einer vom Postfach-Monitor empfangenen Zentralruf-Antwort.
/// Ersetzt den bisherigen In-Memory-Speicher, der bei jedem Neustart verloren
/// ging — empfangene Antworten überdauern nun einen Neustart und müssen nicht
/// neu eingelesen werden. <see cref="VorgangId"/> verweist auf den zugeordneten
/// Vorgang (null, solange keine Zuordnung über die Referenz gelang).
/// </summary>
public class ReceivedReplyEntity
{
    public int Id { get; set; }

    /// <summary>
    /// Stabiler Mail-Schlüssel (Message-Id bzw. UID) für die Dublettenprüfung.
    /// Unique-Index — überdauert jetzt den Neustart, sodass beim Reconnect-
    /// Nachscannen bereits erfasste Mails nicht erneut angelegt werden.
    /// </summary>
    public string DedupeKey { get; set; } = string.Empty;

    public DateTime EmpfangenAm { get; set; }
    public string? Referenz { get; set; }
    public string? Betreff { get; set; }
    public string? Absender { get; set; }

    /// <summary>Serialisierte, geparste ZentralrufReplyData der Antwort.</summary>
    public string? RohdatenJson { get; set; }

    /// <summary>Serialisierte Warnungsliste (mögliche Falschzuordnungen, Negativ-Antwort).</summary>
    public string? WarnungenJson { get; set; }

    /// <summary>Aus der Mail gewonnener Rohtext, der durch den Parser lief (Diagnose/Fallback).</summary>
    public string? Rohtext { get; set; }

    /// <summary>Vom Anwalt als gesehen/übernommen markiert.</summary>
    public bool Quittiert { get; set; }

    /// <summary>True, sobald die Antwort per Referenz einem Vorgang zugeordnet werden konnte.</summary>
    public bool Zugeordnet { get; set; }

    /// <summary>
    /// Vorschlag: der per Referenz gefundene Vorgang. Bewusst nur eine Verknüpfung —
    /// der Vorgang selbst wird nicht automatisch geändert; das Übernehmen bleibt der
    /// bestätigte Schritt im Frontend.
    /// </summary>
    public int? VorgangId { get; set; }

    /// <summary>
    /// True, wenn <see cref="VorgangId"/> nicht über die Referenz, sondern über
    /// den Fallback (Gegner-Kennzeichen + Unfalldatum, eindeutiger Treffer unter
    /// den angefragten Vorgängen) gefunden wurde — eine wahrscheinliche, vom
    /// Anwalt noch zu bestätigende Zuordnung.
    /// </summary>
    public bool ZuordnungVermutet { get; set; }
}
