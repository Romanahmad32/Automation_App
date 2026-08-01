using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

/// <summary>
/// Ergebnis der Antwortmail-Extraktion. <see cref="MissingFields"/> benennt
/// Werte, die im Text nicht gefunden wurden, damit die Oberfläche darauf
/// hinweisen kann (kein fehlerträchtiges stilles Auslassen).
/// <see cref="Warnings"/> enthält Hinweise auf mögliche Falschzuordnungen
/// (z. B. Kennzeichen passt nicht zur Referenz), die der Anwalt prüfen muss.
/// </summary>
public sealed record ZentralrufReplyParseResponseDto(
    bool Success,
    ZentralrufReplyData? Data,
    IReadOnlyList<string> MissingFields,
    IReadOnlyList<string> Warnings,
    string? ErrorCode,
    string? ErrorMessage);
