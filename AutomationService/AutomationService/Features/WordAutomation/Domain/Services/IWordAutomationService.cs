namespace AutomationService.Features.WordAutomation.Domain.Services;

public interface IWordAutomationService
{
    /// <summary>
    /// Füllt eine Word-Vorlage mit den Werten des Auftrags und schreibt das
    /// Ergebnis als neue Datei. Platzhalter ohne Wert bleiben stehen und werden
    /// als Warnung zurückgemeldet.
    /// </summary>
    public DocumentGenerationResult GenerateReplacedDocument(WordReplacementRequest request);

    /// <summary>
    /// Liest alle {{Platzhalter}} aus einer Word-Vorlage aus, ohne das Dokument zu verändern.
    /// Wird vom Frontend genutzt, um beim Verknüpfen einer Vorlage die erkannten
    /// Platzhalter anzuzeigen (Formularvorlagen-Verwaltung).
    /// </summary>
    public IReadOnlyList<string> ExtractPlaceholders(string templateFilePath);

    /// <summary>
    /// Durchläuft die DocX-Pipeline (Create/Load/ReplaceText/SaveAs) einmal mit
    /// einem Wegwerf-Dokument, um den JIT-Aufwand vorzuziehen. Wird beim Start
    /// im Hintergrund aufgerufen, damit der erste echte Request bereits warm ist.
    /// </summary>
    public void Warmup();
}
