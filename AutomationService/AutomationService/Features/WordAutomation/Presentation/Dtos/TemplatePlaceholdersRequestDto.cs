using System.ComponentModel.DataAnnotations;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public class TemplatePlaceholdersRequestDto
{
    [Required]
    [MaxLength(260)]
    public string TemplateFilePath { get; set; } = string.Empty;
}
