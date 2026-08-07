namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>Eine Word-Vorlage aus dem Vorlagenordner des Anwenders.</summary>
public sealed record VorlageDto(string Name, string Pfad, DateTime GeaendertAm);
