namespace AutomationService.Features.WordAutomation.Domain.Exceptions;

/// <summary>
/// Die zu schreibende Ergebnisdatei ist gesperrt — praktisch immer, weil sie
/// aus der Sichtprüfung heraus noch in Word offen ist (§4.5).
///
/// Bewusst <em>keine</em> <see cref="IOException"/>: der Controller beantwortet
/// die mit "Die Word-Datei kann nicht gelesen werden", was hier in die Irre
/// führte — gesperrt ist die Ausgabe, nicht die Vorlage.
/// </summary>
public sealed class ZieldateiGesperrtException(string dateiname, Exception innerException)
    : Exception(
        $"Die Datei \"{dateiname}\" kann nicht überschrieben werden, weil sie noch geöffnet ist " +
        "(meist in Microsoft Word). Bitte schließen Sie das Dokument und erzeugen Sie es erneut.",
        innerException);
