using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public class WordReplacementDto
{
    [Required]
    [MaxLength(260)]
    public string TemplateFilePath { get; set; } = string.Empty;

    public string OutputFileName { get; set; } = string.Empty;

    public string OutputDirectory { get; set; } = string.Empty;
    [Required]
    [MinLength(1)]
    public Dictionary<string, string> ReplacePatterns { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Nur für Vorlagen mit Auflistung; null bei Vorlagen ohne Auflistung (HGN).</summary>
    public DamageListingDto? DamageListing { get; set; }

    /// <summary>
    /// Steuert den Ankreuz-Block "Mein Mandant ☐ ist / ☐ ist nicht
    /// vorsteuerabzugsberechtigt": true kreuzt "ist" an, false "ist nicht".
    /// null = den Block unangetastet lassen (z. B. Vorlagen ohne diesen Abschnitt).
    /// </summary>
    public bool? Vorsteuerabzugsberechtigt { get; set; }
}
