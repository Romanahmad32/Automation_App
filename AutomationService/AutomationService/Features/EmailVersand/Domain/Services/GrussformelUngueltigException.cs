namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Wird geworfen, wenn ein Gruß ohne Text gespeichert werden soll. Der
/// Controller übersetzt das in 400 Bad Request.
/// </summary>
/// <remarks>
/// <c>IsRequired()</c> an der Entität verbietet nur NULL, nicht die leere
/// Zeichenkette — über die API ließ sich damit ein Gruß ohne Wortlaut anlegen
/// (ergänzt am 03.09.2026). Auf dem Schirm war das ein leerer Chip; gewählt
/// hätte er die Grußzeile aus jeder Mail genommen, weil ein leerer Platzhalter
/// seine Zeile mitnimmt. Dieselbe Lücke wie bei den Anredeanfängen
/// (<see cref="AnredeBausteinUngueltigException"/>), dieselbe Antwort — der
/// Dialog im Frontend prüft es längst, und der Bestand ist es, der die Mail
/// schreibt.
/// </remarks>
public sealed class GrussformelUngueltigException(string message) : Exception(message);
