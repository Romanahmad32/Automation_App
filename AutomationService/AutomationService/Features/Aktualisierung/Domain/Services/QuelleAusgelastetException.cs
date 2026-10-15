using System.Net;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// GitHub hat die Prüfung wegen seines Ratenlimits abgewiesen (#199): 429, oder
/// 403 mit <c>X-RateLimit-Remaining: 0</c> bzw. <c>Retry-After</c>. Ohne Anmeldung
/// erlaubt GitHub nur wenige Anfragen je Stunde und Internetanschluss — in einer
/// Kanzlei teilen sich alle Rechner einen.
///
/// Eine eigene Ursache, weil der Anwender sonst „keine Verbindung ins Internet“
/// läse (<see cref="AktualisierungsMeldungen.Ausgelastet"/> statt
/// <see cref="AktualisierungsMeldungen.NichtGeprueft"/>). Abgeleitet von
/// <see cref="HttpRequestException"/>: Wer eine gescheiterte Anfrage erwartet,
/// fängt auch diese.
/// </summary>
/// <param name="message">Für das Protokoll, nie für den Anwender.</param>
/// <param name="status">403 oder 429.</param>
public sealed class QuelleAusgelastetException(string message, HttpStatusCode status)
    : HttpRequestException(message, null, status);
