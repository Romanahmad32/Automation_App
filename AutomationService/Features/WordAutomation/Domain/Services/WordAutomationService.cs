using System.Text.RegularExpressions;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using Microsoft.Extensions.Options;
using Xceed.Document.NET;
using Xceed.Words.NET;

namespace AutomationService.Features.WordAutomation.Domain.Services;

public sealed partial class WordAutomationService : IWordAutomationService
{
    private const string PlaceholderPattern = @"\{\{(.*?)\}\}";
    private readonly ILogger<WordAutomationService> _logger;
    private string _outputDirectory;

    public WordAutomationService(
        ILogger<WordAutomationService> logger,
        IOptions<WordAutomationOptions> options,
        IHostEnvironment hostEnvironment)
    {
        _logger = logger;
        var settings = options.Value;
        _outputDirectory = Path.GetFullPath(Path.Combine(hostEnvironment.ContentRootPath, settings.OutputDirectory));
        Directory.CreateDirectory(_outputDirectory);
    }

    public DocumentGenerationResult GenerateReplacedDocument(WordReplacementDto replacementDto)
    {
        ArgumentNullException.ThrowIfNull(replacementDto);

        if(replacementDto.OutputDirectory != "")
        {
            _outputDirectory = Path.GetFullPath(replacementDto.OutputDirectory);
            Directory.CreateDirectory(_outputDirectory);
        }
        
        var templatePath = replacementDto.TemplateFilePath;
        var rawFileName = Path.GetFileNameWithoutExtension(templatePath);
        var replacementValues = BuildReplacementValues(replacementDto.ReplacePatterns);
        var unresolvedPlaceholders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        using var document = DocX.Load(templatePath);
        var placeholders = document.FindUniqueByPattern(PlaceholderPattern, RegexOptions.IgnoreCase);

        if (placeholders.Count > 0)
        {
            document.ReplaceText(new FunctionReplaceTextOptions
            {
                FindPattern = PlaceholderPattern,
                RegExOptions = RegexOptions.IgnoreCase,
                NewFormatting = new Formatting(),
                RegexMatchHandler = key =>
                {
                    if (replacementValues.TryGetValue(key, out var value))
                        return value;
                    unresolvedPlaceholders.Add(key);
                    return $"{{{{{key}}}}}";
                }
            });
        }

        var outputFileName = $"{rawFileName}_{DateTime.UtcNow:yyyy-MM-dd}_gen.docx";
        var outputPath = Path.Combine(_outputDirectory, outputFileName);
        document.SaveAs(outputPath);

        if (unresolvedPlaceholders.Count > 0)
        {
            _logger.LogWarning(
                "Document generated with unresolved placeholders for template {Template}: {Placeholders}",
                templatePath,
                string.Join(", ", unresolvedPlaceholders));
        }

        return new DocumentGenerationResult(outputPath, unresolvedPlaceholders.ToList());
    }

    private static Dictionary<string, string> BuildReplacementValues(Dictionary<string, string> replacePatterns)
    {
        if (replacePatterns is null)
            throw new ArgumentException("ReplacePatterns is required.", nameof(replacePatterns));

        var values = new Dictionary<string, string>(replacePatterns, StringComparer.OrdinalIgnoreCase)
        {
            ["Today"] = DateTime.UtcNow.ToString("dd.MM.yyyy")
        };

        foreach (var key in values.Keys)
        {
            if (!AllowedPlaceholderKeyPattern().IsMatch(key))
                throw new ArgumentException(
                    $"Placeholder key '{key}' is invalid. Use only letters, digits, '_' or '-'.",
                    nameof(replacePatterns));
        }

        return values;
    }

    [GeneratedRegex("^[A-Za-z0-9_-]+$", RegexOptions.Compiled)]
    private static partial Regex AllowedPlaceholderKeyPattern();
}
