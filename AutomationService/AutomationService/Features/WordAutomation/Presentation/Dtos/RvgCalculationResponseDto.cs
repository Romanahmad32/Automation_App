namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public sealed record RvgCalculationResponseDto(
    bool Success,
    decimal Gegenstandswert,
    decimal Gebuehrensatz,
    decimal Wertgebuehr,
    decimal Geschaeftsgebuehr,
    decimal Auslagenpauschale,
    decimal Netto,
    decimal Umsatzsteuer,
    decimal Brutto,
    string? ErrorCode,
    string? Message);
