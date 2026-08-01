namespace AutomationService.Features.PdfConversion.Domain.Services;

public class PdfConversionOptions
{
    public const string SectionName = "PdfConversion";

    public const string EngineWordInterop = "WordInterop";
    public const string EngineFreeSpire = "FreeSpire";

    /// <summary>"WordInterop" (originalgetreu, benötigt installiertes Word) oder "FreeSpire".</summary>
    public string Engine { get; init; } = EngineWordInterop;

    /// <summary>Relativ zum ContentRoot; hier landen die gecachten Vorschau-PDFs.</summary>
    public string CacheDirectory { get; init; } = Path.Combine("Generated", "PdfCache");

    public int ConversionTimeoutSeconds { get; init; } = 60;

    public bool WarmupOnStartup { get; init; } = true;
}
