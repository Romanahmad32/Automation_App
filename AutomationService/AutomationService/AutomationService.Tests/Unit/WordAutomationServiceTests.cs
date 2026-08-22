using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Kern des Dokumentenerzeugers: Platzhalter ersetzen, unaufgelöste melden,
/// Ausgabedatei benennen. Die beiden Vorlagen-Sonderfälle stehen in
/// <see cref="WordSchadensaufstellungTests"/> und <see cref="WordVorsteuerTests"/>.
/// </summary>
public sealed class WordAutomationServiceTests : IDisposable
{
    private readonly WordVorlagenUmgebung _umgebung = new();

    [Fact]
    public void GenerateReplacedDocument_ReplacesKnownPlaceholders_IgnoresCase()
    {
        var templatePath = _umgebung.CreateTemplate("Letter", "Hello {{FirstName}}, date={{Datum}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string>
            {
                ["firstname"] = "Roman",
                ["datum"] = "12.06.2026"
            }
        });

        File.Exists(result.OutputFilePath).Should().BeTrue();
        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("Roman");
        output.Text.Should().Contain("12.06.2026");
    }

    [Fact]
    public void GenerateReplacedDocument_AllowsGermanPlaceholderKeysWithSpacesAndUmlauts()
    {
        var templatePath = _umgebung.CreateTemplate("German", "{{Vorname Mandant}} aus {{Straße}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string>
            {
                ["Vorname Mandant"] = "Hans",
                ["Straße"] = "Hauptweg 1"
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("Hans aus Hauptweg 1");
        result.Warnings.Should().BeEmpty();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenKeyContainsBraces_ThrowsArgumentException()
    {
        var templatePath = _umgebung.CreateTemplate("Invalid", "{{ok}}");

        var service = _umgebung.CreateService();
        var action = () => service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Bad{Key"] = "x" }
        });

        action.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenTemplateMissing_ThrowsFileNotFoundException()
    {
        var service = _umgebung.CreateService();

        var action = () => service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = _umgebung.TemplatePath("DoesNotExist.docx"),
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" }
        });

        action.Should().Throw<FileNotFoundException>();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenPlaceholderMissing_ReturnsWarningAndKeepsTag()
    {
        var templatePath = _umgebung.CreateTemplate("Contract", "Value={{Known}} Missing={{Unknown}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Known"] = "ok" }
        });

        result.Warnings.Should().Contain("Unknown");
        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("{{Unknown}}");
    }

    /// <summary>
    /// Der Kern der Korrekturschleife: wer sich vertippt hat, geht zurück und
    /// erzeugt neu. Früher entstand dabei "Ergebnis (2).docx" — und mit ihr die
    /// Frage, welche der beiden Fassungen der Anwalt geprüft hat.
    /// </summary>
    [Fact]
    public void GenerateReplacedDocument_WhenGeneratedAgain_OverwritesInsteadOfVersioning()
    {
        var templatePath = _umgebung.CreateTemplate("Brief", "Hallo {{Name}}");

        var service = _umgebung.CreateService();

        var first = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            OutputFileName = "Ergebnis",
            VorgangSchluessel = "84/26 C03_GG-XY 123",
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "A" }
        });
        var second = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            OutputFileName = "Ergebnis",
            VorgangSchluessel = "84/26 C03_GG-XY 123",
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "B" }
        });

        second.OutputFilePath.Should().Be(first.OutputFilePath);
        Directory.GetFiles(Path.GetDirectoryName(first.OutputFilePath)!)
            .Should().ContainSingle("die Korrektur ersetzt die Fassung, statt eine zweite anzulegen");
        using var output = DocX.Load(second.OutputFilePath);
        output.Text.Should().Contain("Hallo B");
    }

    /// <summary>
    /// Der Dateiname besteht nur aus Vorlage und Unfalldatum — zwei Vorgänge
    /// treffen sich darin. Getrennt hält sie erst der Arbeitsordner; ohne ihn
    /// überschriebe der zweite Vorgang das ungesicherte Schreiben des ersten.
    /// </summary>
    [Fact]
    public void GenerateReplacedDocument_SeparatesVorgaengeIntoOwnFolders()
    {
        var templatePath = _umgebung.CreateTemplate("Brief", "Hallo {{Name}}");

        var service = _umgebung.CreateService();

        var ersterVorgang = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            OutputFileName = "VORLAGE HGN 12.06.2026",
            VorgangSchluessel = "84/26 C03_GG-XY 123",
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Müller" }
        });
        var zweiterVorgang = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            OutputFileName = "VORLAGE HGN 12.06.2026",
            VorgangSchluessel = "85/26 C03_HG-E 1427",
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Schmidt" }
        });

        zweiterVorgang.OutputFilePath.Should().NotBe(ersterVorgang.OutputFilePath);
        File.Exists(ersterVorgang.OutputFilePath).Should().BeTrue();
        using var ersteFassung = DocX.Load(ersterVorgang.OutputFilePath);
        ersteFassung.Text.Should().Contain("Hallo Müller");
    }

    [Fact]
    public void GenerateReplacedDocument_WithoutVorgang_WritesToFreeFolder()
    {
        var templatePath = _umgebung.CreateTemplate("Frei", "Hallo {{Name}}");

        var result = _umgebung.CreateService().GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            OutputFileName = "Ergebnis",
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "A" }
        });

        Path.GetFileName(Path.GetDirectoryName(result.OutputFilePath))
            .Should().Be(ArbeitsVerzeichnis.OhneVorgang);
    }

    [Fact]
    public void ExtractPlaceholders_ReturnsDistinctPlaceholderNames()
    {
        var templatePath = _umgebung.CreateTemplate(
            "Scan",
            "Hallo {{Vorname Mandant}}, Kennzeichen {{Kennzeichen}}, nochmal {{vorname mandant}}.");

        var service = _umgebung.CreateService();
        var placeholders = service.ExtractPlaceholders(templatePath);

        placeholders.Should().BeEquivalentTo(["Vorname Mandant", "Kennzeichen"]);
    }

    [Fact]
    public void ExtractPlaceholders_WhenTemplateHasNoPlaceholders_ReturnsEmptyList()
    {
        var templatePath = _umgebung.CreateTemplate("Plain", "Nur normaler Text ohne Felder.");

        var service = _umgebung.CreateService();

        service.ExtractPlaceholders(templatePath).Should().BeEmpty();
    }

    [Fact]
    public void ExtractPlaceholders_WhenTemplateMissing_ThrowsFileNotFoundException()
    {
        var service = _umgebung.CreateService();

        var action = () => service.ExtractPlaceholders(_umgebung.TemplatePath("DoesNotExist.docx"));

        action.Should().Throw<FileNotFoundException>();
    }

    public void Dispose() => _umgebung.Dispose();
}
