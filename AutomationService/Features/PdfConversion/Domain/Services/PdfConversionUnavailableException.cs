namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>
/// Wird geworfen, wenn keine der konfigurierten Engines das Dokument
/// konvertieren konnte (z. B. Word nicht installiert und FreeSpire fehlgeschlagen).
/// </summary>
public class PdfConversionUnavailableException(string message, Exception? innerException = null)
    : Exception(message, innerException);
