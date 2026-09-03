using System.ComponentModel.DataAnnotations;
using AutomationService.Core.ErrorHandling;

namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

public class TemplatePlaceholdersRequestDto
{
    [Display(Name = "Die Vorlagendatei")]
    [Required(ErrorMessage = Validierungstexte.Pflicht)]
    [MaxLength(260, ErrorMessage = Validierungstexte.MaxZeichen)]
    public string TemplateFilePath { get; set; } = string.Empty;
}
