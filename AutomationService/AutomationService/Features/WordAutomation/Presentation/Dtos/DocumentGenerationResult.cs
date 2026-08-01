namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public sealed record DocumentGenerationResult(string OutputFilePath, IReadOnlyList<string> Warnings);
