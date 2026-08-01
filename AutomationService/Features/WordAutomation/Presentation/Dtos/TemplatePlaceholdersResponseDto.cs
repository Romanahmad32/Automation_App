namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public sealed record TemplatePlaceholdersResponseDto(
    bool Success,
    IReadOnlyList<string> Placeholders,
    string? ErrorCode,
    string? Message);
