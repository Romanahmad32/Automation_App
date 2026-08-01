using AutomationService.Features.WordAutomation.Presentation.Dtos;

namespace AutomationService.Features.WordAutomation.Domain.Services;

public interface IWordAutomationService
{
    public DocumentGenerationResult GenerateReplacedDocument(WordReplacementDto replacementDto);

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
