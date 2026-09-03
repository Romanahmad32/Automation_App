namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Wird geworfen, wenn einem Anredeanfang eine seiner drei Formen fehlt. Der
/// Controller übersetzt das in 400 Bad Request.
/// </summary>
/// <remarks>
/// <c>IsRequired()</c> an der Entität verbietet nur NULL, nicht die leere
/// Zeichenkette — über die API ließ sich damit ein namenloser Anredeanfang
/// anlegen (ergänzt am 02.09.2026). Auf dem Schirm war das ein leerer Chip,
/// und stand er vorn, wurde er zur Vorgabe: Jede Mail begann dann ohne
/// Anredebeginn, nur mit „Herr Müller". Der Dialog im Frontend hat diese
/// Prüfung längst; sie gehört auch hierher, denn der Bestand ist es, der die
/// Mail schreibt.
/// </remarks>
public sealed class AnredeBausteinUngueltigException(string message) : Exception(message);
