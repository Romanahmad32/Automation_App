namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public sealed record ReplacedDocumentResponseDto(
    bool Success,
    string? OutputFilePath,
    IReadOnlyList<string> Warnings,
    string? ErrorCode,
    string? Message);
