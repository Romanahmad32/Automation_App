using System.IO.Compression;
using System.Xml.Linq;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Features.WordAutomation.Presentation.Dtos;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

public sealed class WordAutomationServiceTests : IDisposable
{
    private readonly string _contentRoot;

    public WordAutomationServiceTests()
    {
        _contentRoot = Path.Combine(Path.GetTempPath(), $"AutomationServiceTests_{Guid.NewGuid():N}");
        Directory.CreateDirectory(Path.Combine(_contentRoot, "Templates"));
        Directory.CreateDirectory(Path.Combine(_contentRoot, "Generated"));
    }

    [Fact]
    public void GenerateReplacedDocument_ReplacesKnownPlaceholders_IgnoresCase()
    {
        var templatePath = CreateTemplate("Letter", "Hello {{FirstName}}, date={{Datum}}");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
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
        var templatePath = CreateTemplate("German", "{{Vorname Mandant}} aus {{Straße}}");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
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
        var templatePath = CreateTemplate("Invalid", "{{ok}}");

        var service = CreateService();
        var action = () => service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Bad{Key"] = "x" }
        });

        action.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenTemplateMissing_ThrowsFileNotFoundException()
    {
        var service = CreateService();

        var action = () => service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = Path.Combine(_contentRoot, "Templates", "DoesNotExist.docx"),
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" }
        });

        action.Should().Throw<FileNotFoundException>();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenPlaceholderMissing_ReturnsWarningAndKeepsTag()
    {
        var templatePath = CreateTemplate("Contract", "Value={{Known}} Missing={{Unknown}}");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Known"] = "ok" }
        });

        result.Warnings.Should().Contain("Unknown");
        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("{{Unknown}}");
    }

    [Fact]
    public void GenerateReplacedDocument_WhenOutputExists_DoesNotOverwrite()
    {
        var templatePath = CreateTemplate("Brief", "Hallo {{Name}}");

        var service = CreateService();

        var first = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            OutputFileName = "Ergebnis",
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "A" }
        });
        var second = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            OutputFileName = "Ergebnis",
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "B" }
        });

        second.OutputFilePath.Should().NotBe(first.OutputFilePath);
        File.Exists(first.OutputFilePath).Should().BeTrue();
        File.Exists(second.OutputFilePath).Should().BeTrue();
    }

    [Fact]
    public void GenerateReplacedDocument_WithDamageListing_BuildsTableInKanzleiLayout()
    {
        var templatePath = CreateTemplate(
            "Auflistung",
            "Schaden: {{Schadensaufstellung}} Netto: {{RvgNetto}}");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListingDto
            {
                Items =
                [
                    new DamageItemDto { Description = "Reparaturkosten netto nach Gutachten", Amount = 2560.87m },
                    new DamageItemDto { Description = "Wertminderung nach Gutachten", Amount = 250m }
                ],
                Gebuehrensatz = 1.3m,
                ApplyVat = false
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        var table = output.Tables.Should().ContainSingle().Subject;

        table.ColumnCount.Should().Be(3);
        // Kopfzeile + 2 Positionen + Leerzeile + Zwischensumme + Anwaltskosten
        table.Rows.Should().HaveCount(6);
        table.Rows[0].Cells[0].Paragraphs[0].Text.Should().Be("Position");
        table.Rows[0].Cells[1].Paragraphs[0].Text.Should().Be("Bezeichnung");
        table.Rows[0].Cells[2].Paragraphs[0].Text.Should().Be("Forderung in €");
        table.Rows[1].Cells[0].Paragraphs[0].Text.Should().Be("1");
        table.Rows[1].Cells[1].Paragraphs[0].Text.Should().Be("Reparaturkosten netto nach Gutachten");
        table.Rows[1].Cells[2].Paragraphs[0].Text.Should().Be("2.560,87");
        // Leerzeile als optischer Abstand (wie im Excel-Vorbild der Kanzlei)
        table.Rows[3].Cells.SelectMany(cell => cell.Paragraphs).Should().OnlyContain(p => p.Text == string.Empty);
        table.Rows[4].Cells[1].Paragraphs[0].Text.Should().Be("Zwischensumme (ohne RA-Kosten)");
        table.Rows[4].Cells[2].Paragraphs[0].Text.Should().Be("2.810,87");
        table.Rows[5].Cells[1].Paragraphs[0].Text.Should().Be("Anwaltskosten nach RVG");

        output.Text.Should().NotContain("{{Schadensaufstellung}}");
    }

    [Fact]
    public void GenerateReplacedDocument_WithDamageListing_StylesTableLikeExcelVorbild()
    {
        var templatePath = CreateTemplate("AuflistungStyling", "{{Schadensaufstellung}}");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListingDto
            {
                Items =
                [
                    new DamageItemDto { Description = "Reparaturkosten", Amount = 1000m },
                    new DamageItemDto { Description = "Wertminderung", Amount = 200m },
                    new DamageItemDto { Description = "Unkostenpauschale", Amount = 30m }
                ]
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        var table = output.Tables.Should().ContainSingle().Subject;

        // Horizontal zentriert (w:jc im tblPr).
        table.Xml.ToString().Should().Contain("<w:jc w:val=\"center\"");

        // Kopfzeile grau schattiert, jede zweite Positionszeile als Zebra-Streifen.
        var headerXml = table.Rows[0].Cells[0].Xml.ToString().ToLowerInvariant();
        headerXml.Should().Contain("w:shd").And.Contain("d9d9d9");
        var bandedXml = table.Rows[2].Cells[0].Xml.ToString().ToLowerInvariant();
        bandedXml.Should().Contain("w:shd").And.Contain("f2f2f2");
        table.Rows[1].Cells[0].Xml.ToString().ToLowerInvariant().Should().NotContain("f2f2f2");

        // Zwischensummen-Zeile (Index 5: Kopf + 3 Positionen + Leerzeile) mit dicker Ober-/Unterkante.
        var subtotalXml = table.Rows[5].Cells[1].Xml.ToString();
        subtotalXml.Should().Contain("<w:top").And.Contain("<w:bottom");
    }

    [Fact]
    public void GenerateReplacedDocument_WithConfiguredHeaderColor_ShadesHeaderAndBandedRows()
    {
        var templatePath = CreateTemplate("AuflistungFarbe", "{{Schadensaufstellung}}");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListingDto
            {
                Items =
                [
                    new DamageItemDto { Description = "Reparaturkosten", Amount = 1000m },
                    new DamageItemDto { Description = "Wertminderung", Amount = 200m }
                ],
                HeaderColorHex = "#B4C6E7"
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        var table = output.Tables.Should().ContainSingle().Subject;

        var headerXml = table.Rows[0].Cells[0].Xml.ToString().ToLowerInvariant();
        headerXml.Should().Contain("w:shd").And.Contain("b4c6e7");
        // Zebra-Streifen werden aus der Kopffarbe abgeleitet (aufgehellt), nicht mehr fix F2F2F2.
        var bandedXml = table.Rows[2].Cells[0].Xml.ToString().ToLowerInvariant();
        bandedXml.Should().Contain("w:shd").And.NotContain("f2f2f2").And.NotContain("b4c6e7");
    }

    [Fact]
    public void GenerateReplacedDocument_WithRvgOverrides_UsesCorrectedFeesInPlaceholders()
    {
        // Die RVG-Platzhalter müssen in einem eigenen Absatz stehen — der Absatz
        // mit {{Schadensaufstellung}} wird beim Einfügen der Tabelle entfernt.
        var templatePath = CreateTemplate(
            "AuflistungKorrigiert",
            "{{Schadensaufstellung}}",
            "Gebühr: {{Geschaeftsgebuehr}} Auslagen: {{Auslagenpauschale}}");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListingDto
            {
                Items = [new DamageItemDto { Description = "Reparaturkosten", Amount = 1000m }],
                GeschaeftsgebuehrOverride = 150.00m,
                AuslagenpauschaleOverride = 25.00m
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("Gebühr: 150,00");
        output.Text.Should().Contain("Auslagen: 25,00");
    }

    [Fact]
    public void ExtractPlaceholders_ReturnsDistinctPlaceholderNames()
    {
        var templatePath = CreateTemplate(
            "Scan",
            "Hallo {{Vorname Mandant}}, Kennzeichen {{Kennzeichen}}, nochmal {{vorname mandant}}.");

        var service = CreateService();
        var placeholders = service.ExtractPlaceholders(templatePath);

        placeholders.Should().BeEquivalentTo(["Vorname Mandant", "Kennzeichen"]);
    }

    [Fact]
    public void ExtractPlaceholders_WhenTemplateHasNoPlaceholders_ReturnsEmptyList()
    {
        var templatePath = CreateTemplate("Plain", "Nur normaler Text ohne Felder.");

        var service = CreateService();

        service.ExtractPlaceholders(templatePath).Should().BeEmpty();
    }

    [Fact]
    public void ExtractPlaceholders_WhenTemplateMissing_ThrowsFileNotFoundException()
    {
        var service = CreateService();

        var action = () => service.ExtractPlaceholders(
            Path.Combine(_contentRoot, "Templates", "DoesNotExist.docx"));

        action.Should().Throw<FileNotFoundException>();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenVorsteuerTrue_ChecksIst_UnchecksIstNicht()
    {
        // Standard der Vorlage bewusst umgekehrt, damit der Tausch sichtbar wird.
        var templatePath = CreateTemplate(
            "VorsteuerJa",
            "Mein Mandant",
            "☐ ist",
            "☒ ist nicht vorsteuerabzugsberechtigt.");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            Vorsteuerabzugsberechtigt = true
        });

        using var output = DocX.Load(result.OutputFilePath);
        var positive = output.Paragraphs.Single(p =>
            p.Text.Contains("ist") && !p.Text.Contains("nicht") &&
            (p.Text.Contains('☐') || p.Text.Contains('☒')));
        var negative = output.Paragraphs.Single(p => p.Text.Contains("vorsteuerabzugsberechtigt"));

        positive.Text.Should().Contain("☒").And.NotContain("☐");
        negative.Text.Should().Contain("☐").And.NotContain("☒");
        result.Warnings.Should().BeEmpty();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenVorsteuerFalse_ChecksIstNicht_UnchecksIst()
    {
        var templatePath = CreateTemplate(
            "VorsteuerNein",
            "Mein Mandant",
            "☒ ist",
            "☐ ist nicht vorsteuerabzugsberechtigt.");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            Vorsteuerabzugsberechtigt = false
        });

        using var output = DocX.Load(result.OutputFilePath);
        var positive = output.Paragraphs.Single(p =>
            p.Text.Contains("ist") && !p.Text.Contains("nicht") &&
            (p.Text.Contains('☐') || p.Text.Contains('☒')));
        var negative = output.Paragraphs.Single(p => p.Text.Contains("vorsteuerabzugsberechtigt"));

        positive.Text.Should().Contain("☐").And.NotContain("☒");
        negative.Text.Should().Contain("☒").And.NotContain("☐");
    }

    [Fact]
    public void GenerateReplacedDocument_WhenVorsteuerNull_LeavesCheckboxesUntouched()
    {
        var templatePath = CreateTemplate(
            "VorsteuerUnberuehrt",
            "Mein Mandant",
            "☒ ist",
            "☐ ist nicht vorsteuerabzugsberechtigt.");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" }
            // Vorsteuerabzugsberechtigt = null → Block bleibt unangetastet
        });

        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("☒ ist");
        output.Paragraphs.Single(p => p.Text.Contains("vorsteuerabzugsberechtigt"))
            .Text.Should().Contain("☐");
    }

    [Fact]
    public void GenerateReplacedDocument_WhenVorsteuerBlockMissing_AddsWarning()
    {
        var templatePath = CreateTemplate("OhneVorsteuer", "Ein Brief ohne den Abschnitt {{Name}}.");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Name"] = "Roman" },
            Vorsteuerabzugsberechtigt = true
        });

        result.Warnings.Should().ContainSingle(w => w.Contains("vorsteuerabzugsberechtigt"));
    }

    [Fact]
    public void GenerateReplacedDocument_WhenVorsteuerSeparateParagraphAnchor_StillToggles()
    {
        // Anker steht – wie in echten Vorlagen – in einem eigenen Absatz,
        // getrennt von den Kästchen-Zeilen.
        var templatePath = CreateTemplate(
            "VorsteuerGetrennt",
            "Mein Mandant",
            "☐ ist",
            "☒ ist nicht",
            "vorsteuerabzugsberechtigt.");

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            Vorsteuerabzugsberechtigt = true
        });

        using var output = DocX.Load(result.OutputFilePath);
        var positive = output.Paragraphs.Single(p =>
            p.Text.Trim() == "☐ ist" || p.Text.Trim() == "☒ ist");
        var negative = output.Paragraphs.Single(p => p.Text.Contains("ist nicht"));
        positive.Text.Should().Contain("☒");
        negative.Text.Should().Contain("☐");
        result.Warnings.Should().BeEmpty();
    }

    [Fact]
    public void GenerateReplacedDocument_WhenWordCheckboxControls_TogglesCheckedStateAndGlyph()
    {
        // Echte Kanzlei-Vorlage mit Word-Kontrollkästchen (sdt/w14:checkbox).
        var samplePath = FindBeispielTemplate("VORLAGE Fahrspurwechsel mit Auflistung.docx");
        if (samplePath is null)
        {
            return; // Beispieldatei nicht verfügbar (z. B. CI) → übersprungen.
        }

        var service = CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementDto
        {
            TemplateFilePath = samplePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            Vorsteuerabzugsberechtigt = false
        });

        result.Warnings.Should().NotContain(w => w.Contains("vorsteuerabzugsberechtigt"));

        var (checkedGlyphs, uncheckedGlyphs) = ReadCheckboxStates(result.OutputFilePath);
        // Der Vorsteuer-Block hat genau zwei Kontrollkästchen. Bei "nicht
        // vorsteuerabzugsberechtigt" ist genau die "ist nicht"-Box angekreuzt.
        checkedGlyphs.Should().ContainSingle().Which.Should().Be("☒");
        uncheckedGlyphs.Should().ContainSingle().Which.Should().Be("☐");
    }

    /// <summary>Sucht ab dem Test-Arbeitsverzeichnis aufwärts nach Beispiele/&lt;name&gt;.</summary>
    private static string? FindBeispielTemplate(string fileName)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "Beispiele", fileName);
            if (File.Exists(candidate))
                return candidate;
            dir = dir.Parent;
        }
        return null;
    }

    /// <summary>Liest pro Word-Kontrollkästchen das angezeigte Glyph, getrennt nach
    /// checked (w14:checked val="1") und unchecked.</summary>
    private static (List<string> Checked, List<string> Unchecked) ReadCheckboxStates(string docxPath)
    {
        const string w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
        using var archive = ZipFile.OpenRead(docxPath);
        var entry = archive.GetEntry("word/document.xml")!;
        using var stream = entry.Open();
        var document = XDocument.Load(stream);

        var checkedGlyphs = new List<string>();
        var uncheckedGlyphs = new List<string>();
        foreach (var sdt in document.Descendants()
                     .Where(e => e.Name.LocalName == "sdt"
                         && e.Descendants().Any(c => c.Name.LocalName == "checkbox")))
        {
            var isChecked = sdt.Descendants().First(e => e.Name.LocalName == "checked")
                .Attributes().First(a => a.Name.LocalName == "val").Value == "1";
            var glyph = sdt.Descendants(XName.Get("t", w)).First().Value;
            (isChecked ? checkedGlyphs : uncheckedGlyphs).Add(glyph);
        }
        return (checkedGlyphs, uncheckedGlyphs);
    }

    private string CreateTemplate(string name, params string[] paragraphs)
    {
        var path = Path.Combine(_contentRoot, "Templates", $"{name}.docx");
        using var document = DocX.Create(path);
        foreach (var paragraph in paragraphs)
            document.InsertParagraph(paragraph);
        document.Save();
        return path;
    }

    private WordAutomationService CreateService()
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
