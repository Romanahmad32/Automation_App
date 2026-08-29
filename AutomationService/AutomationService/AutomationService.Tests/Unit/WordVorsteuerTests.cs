using System.IO.Compression;
using System.Xml.Linq;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Ankreuzblock "Mein Mandant ☐ ist / ☐ ist nicht
/// vorsteuerabzugsberechtigt" — beide Schreibweisen der Vorlagen (literale
/// Kästchen-Glyphen und Word-Kontrollkästchen) und der Fall, dass die Vorlage
/// den Abschnitt gar nicht hat.
/// </summary>
public sealed class WordVorsteuerTests : IDisposable
{
    private readonly WordVorlagenUmgebung _umgebung = new();

    [Fact]
    public void GenerateReplacedDocument_WhenVorsteuerTrue_ChecksIst_UnchecksIstNicht()
    {
        // Standard der Vorlage bewusst umgekehrt, damit der Tausch sichtbar wird.
        var templatePath = _umgebung.CreateTemplate(
            "VorsteuerJa",
            "Mein Mandant",
            "☐ ist",
            "☒ ist nicht vorsteuerabzugsberechtigt.");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
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
        var templatePath = _umgebung.CreateTemplate(
            "VorsteuerNein",
            "Mein Mandant",
            "☒ ist",
            "☐ ist nicht vorsteuerabzugsberechtigt.");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
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
        var templatePath = _umgebung.CreateTemplate(
            "VorsteuerUnberuehrt",
            "Mein Mandant",
            "☒ ist",
            "☐ ist nicht vorsteuerabzugsberechtigt.");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
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
        var templatePath = _umgebung.CreateTemplate("OhneVorsteuer", "Ein Brief ohne den Abschnitt {{Name}}.");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
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
        var templatePath = _umgebung.CreateTemplate(
            "VorsteuerGetrennt",
            "Mein Mandant",
            "☐ ist",
            "☒ ist nicht",
            "vorsteuerabzugsberechtigt.");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
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
        // Vorlage mit Word-Kontrollkästchen (sdt/w14:checkbox), im Aufbau der
        // Kanzlei-Vorlage: Ausgangszustand bewusst verkehrt herum, damit der
        // Tausch beider Kästchen sichtbar wird.
        var templatePath = _umgebung.CreateTemplateWithWordCheckboxes(
            "VorsteuerKontrollkaestchen",
            (" ist", true),
            (" ist nicht vorsteuerabzugsberechtigt.", false));

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            Vorsteuerabzugsberechtigt = false
        });

        result.Warnings.Should().NotContain(w => w.Contains("vorsteuerabzugsberechtigt"));

        var kaestchen = ReadCheckboxStates(result.OutputFilePath);
        kaestchen.Should().HaveCount(2);

        // Beide Kästchen kippen, und zwar Zustand *und* Glyph: Word zeigt das
        // Glyph an, ausgewertet wird w14:checked. Wer nur eines von beiden
        // setzt, bekommt ein Dokument, das anders aussieht, als es gemeint ist.
        var negativ = kaestchen.Single(k => k.Text.Contains("nicht"));
        var positiv = kaestchen.Single(k => !k.Text.Contains("nicht"));

        negativ.Checked.Should().BeTrue();
        negativ.Glyph.Should().Be("☒");
        positiv.Checked.Should().BeFalse();
        positiv.Glyph.Should().Be("☐");
    }

    /// <summary>
    /// Liest je Word-Kontrollkästchen den Absatztext, den Zustand
    /// (w14:checked val="1") und das angezeigte Glyph.
    ///
    /// Der Absatztext gehört dazu: Ohne ihn bliebe offen, ob das *richtige*
    /// Kästchen angekreuzt ist. Bei zwei Kästchen mit vertauschtem Ausgangs-
    /// zustand käme ein Dienst, der gar nichts tut, durch eine Prüfung, die
    /// nur angekreuzte und leere Kästchen zählt.
    /// </summary>
    private static List<(string Text, bool Checked, string Glyph)> ReadCheckboxStates(string docxPath)
    {
        const string w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
        using var archive = ZipFile.OpenRead(docxPath);
        var entry = archive.GetEntry("word/document.xml")!;
        using var stream = entry.Open();
        var document = XDocument.Load(stream);

        var kaestchen = new List<(string, bool, string)>();
        foreach (var sdt in document.Descendants()
                     .Where(e => e.Name.LocalName == "sdt"
                         && e.Descendants().Any(c => c.Name.LocalName == "checkbox")))
        {
            var isChecked = sdt.Descendants().First(e => e.Name.LocalName == "checked")
                .Attributes().First(a => a.Name.LocalName == "val").Value == "1";
            var glyph = sdt.Descendants(XName.Get("t", w)).First().Value;
            var absatz = sdt.Ancestors().First(e => e.Name.LocalName == "p");
            var text = string.Concat(absatz.Descendants(XName.Get("t", w)).Select(t => t.Value));
            kaestchen.Add((text, isChecked, glyph));
        }
        return kaestchen;
    }

    public void Dispose() => _umgebung.Dispose();
}
