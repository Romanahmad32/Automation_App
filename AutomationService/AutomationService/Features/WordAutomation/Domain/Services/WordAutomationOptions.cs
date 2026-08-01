namespace AutomationService.Features.WordAutomation.Domain.Services;

public class WordAutomationOptions
{
    public const string SectionName = "WordAutomation";

    public string TemplatesDirectory { get; init; } = "Templates";

    public string OutputDirectory { get; init; } = "Generated";
}
