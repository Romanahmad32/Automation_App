namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

public sealed record ZentralrufPrefillResponseDto(
    bool Success,
    string? Referenz,
    IReadOnlyList<string> FilledFields,
    IReadOnlyList<string> SkippedFields,
    string? ErrorCode,
    string? Message);
