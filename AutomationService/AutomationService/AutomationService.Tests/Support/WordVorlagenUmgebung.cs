using AutomationService.Features.WordAutomation.Domain.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xceed.Words.NET;

namespace AutomationService.Tests.Support;

/// <summary>
/// Wegwerf-Arbeitsverzeichnis mit Templates/ und Generated/Arbeit/ für die Tests des
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
        ArbeitsVerzeichnis = new ArbeitsVerzeichnis(
            Path.Combine(_contentRoot, "Generated", "Arbeit"),
            NullLogger<ArbeitsVerzeichnis>.Instance);
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

    /// <summary>Die Wurzel der Arbeitsordner (Generated/Arbeit) dieser Umgebung.</summary>
    public ArbeitsVerzeichnis ArbeitsVerzeichnis { get; }

    public WordAutomationService CreateService() =>
        new(NullLogger<WordAutomationService>.Instance, ArbeitsVerzeichnis);

    public void Dispose()
    {
        if (Directory.Exists(_contentRoot))
        {
            Directory.Delete(_contentRoot, true);
        }
    }
}
