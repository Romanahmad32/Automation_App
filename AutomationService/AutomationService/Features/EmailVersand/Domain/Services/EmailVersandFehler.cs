namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Woran der Versand gescheitert ist. Bestimmt im Controller den Statuscode:
/// Was der Anwalt selbst beheben kann, ist eine 400 — was der Server verweigert
/// hat, eine 502.
/// </summary>
public enum EmailVersandFehler
{
    /// <summary>Kein (vollständiger) Postfach-Zugang hinterlegt.</summary>
    KeinZugang,

    /// <summary>Empfänger fehlt oder ist keine gültige Adresse.</summary>
    Adresse,

    /// <summary>Ein Anhang fehlt, ist gesperrt oder alle zusammen sind zu groß.</summary>
    Anhang,

    /// <summary>Der Server hat die Anmeldung abgelehnt (Passwort, abgelaufenes Token).</summary>
    Anmeldung,

    /// <summary>Der Server war nicht erreichbar oder hat die Nachricht abgewiesen.</summary>
    Server,

    /// <summary>Der Entwurf liess sich in keinem Mailprogramm oeffnen.</summary>
    Entwurf,
}
