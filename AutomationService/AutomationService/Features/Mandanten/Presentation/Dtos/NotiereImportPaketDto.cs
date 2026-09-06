namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Verbucht ein soeben herausgegebenes Arbeitspaket. Nur die Ordnernamen —
/// die Nummer vergibt das Backend, denn nur es sieht alle bisherigen Pakete.
/// Eine vom Aufrufer mitgeschickte Nummer wäre eine Behauptung, die zwei
/// Rechner gleichzeitig aufstellen könnten.
/// </summary>
public sealed record NotiereImportPaketDto(IReadOnlyList<string> Ordnernamen);
