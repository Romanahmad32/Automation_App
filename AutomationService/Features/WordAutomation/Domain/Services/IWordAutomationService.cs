using AutomationService.Features.WordAutomation.Presentation.Dtos;

namespace AutomationService.Features.WordAutomation.Domain.Services;

public interface IWordAutomationService
{
    public DocumentGenerationResult GenerateReplacedDocument(WordReplacementDto replacementDto);
}
