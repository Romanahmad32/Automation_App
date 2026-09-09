namespace AutomationService.Features.Backup.Presentation.Dtos;

/// <summary>Bindet die Bestätigung an genau den angezeigten fremden und lokalen Stand.</summary>
public sealed record UebernahmeAuftragDto(string? Pruefkennung, bool KonfliktBestaetigt = false);
