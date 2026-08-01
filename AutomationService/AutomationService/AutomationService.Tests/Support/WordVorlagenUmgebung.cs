using AutomationService.Features.WordAutomation.Domain.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xceed.Words.NET;

namespace AutomationService.Tests.Support;

/// <summary>
/// Wegwerf-Arbeitsverzeichnis mit Templates/ und Generated/ für die Tests des
/// Dokumentenerzeugers: legt Vorlagen an, baut den Dienst darauf und räumt am
/// Ende alles weg. Jede Testklasse bekommt ihr eigenes Verzeichnis, damit die
/// Klassen parallel laufen können, ohne sich Dateien wegzuschreiben.
/// </summary>
public sealed class WordVorlagenUmgebung : IDisposable
{
    private readonly string _contentRoot;

    public WordVorlagenUmgebung()
    {
        _contentRoot = Path.Combine(Path.GetTempPath(), $"AutomationServiceTests_{Guid.NewGuid():N}");
        Directory.CreateDirectory(Path.Combine(_contentRoot, "Templates"));
        Directory.CreateDirectory(Path.Combine(_contentRoot, "Generated"));
    }

    /// <summary>Legt eine .docx mit je einem Absatz pro übergebenem Text an.</summary>
    public string CreateTemplate(string name, params string[] paragraphs)
    {
        var path = Path.Combine(_contentRoot, "Templates", $"{name}.docx");
        using var document = DocX.Create(path);
        foreach (var paragraph in paragraphs)
            document.InsertParagraph(paragraph);
        document.Save();
        return path;
    }

    /// <summary>Pfad im Arbeitsverzeichnis — für Tests, die eine fehlende Datei brauchen.</summary>
    public string TemplatePath(string fileName) => Path.Combine(_contentRoot, "Templates", fileName);

    public WordAutomationService CreateService()
    {
        var options = Options.Create(new WordAutomationOptions
        {
            TemplatesDirectory = "Templates",
            OutputDirectory = "Generated"
        });

        return new WordAutomationService(
            NullLogger<WordAutomationService>.Instance,
            options,
            new FakeHostEnvironment(_contentRoot));
    }

    public void Dispose()
    {
        if (Directory.Exists(_contentRoot))
        {
            Directory.Delete(_contentRoot, true);
        }
    }
}
