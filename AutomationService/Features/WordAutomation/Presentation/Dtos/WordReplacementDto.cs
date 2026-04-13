using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public class WordReplacementDto
{
    [Required]
    [MaxLength(120)]
    public string TemplateFilePath { get; set; } = string.Empty;

    public string OutputFileName { get; set; } = string.Empty;
    
    public string OutputDirectory { get; set; } = string.Empty;
    [Required]
    [MinLength(1)]
    public Dictionary<string, string> ReplacePatterns { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
