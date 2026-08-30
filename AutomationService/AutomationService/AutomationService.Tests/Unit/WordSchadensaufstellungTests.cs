using System.Xml.Linq;
using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Schadensaufstellung als Word-Tabelle: Aufbau, Gestaltung im Layout des
/// Excel-Vorbilds der Kanzlei und die manuell korrigierten RVG-Beträge.
/// </summary>
public sealed class WordSchadensaufstellungTests : IDisposable
{
    private readonly WordVorlagenUmgebung _umgebung = new();

    [Fact]
    public void GenerateReplacedDocument_WithDamageListing_BuildsTableInKanzleiLayout()
    {
        var templatePath = _umgebung.CreateTemplate(
            "Auflistung",
            "Schaden: {{Schadensaufstellung}} Netto: {{RvgNetto}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListing
            {
                Items =
                [
                    new DamageItem { Description = "Reparaturkosten netto nach Gutachten", Amount = 2560.87m },
                    new DamageItem { Description = "Wertminderung nach Gutachten", Amount = 250m }
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
        var templatePath = _umgebung.CreateTemplate("AuflistungStyling", "{{Schadensaufstellung}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListing
            {
                Items =
                [
                    new DamageItem { Description = "Reparaturkosten", Amount = 1000m },
                    new DamageItem { Description = "Wertminderung", Amount = 200m },
                    new DamageItem { Description = "Unkostenpauschale", Amount = 30m }
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
        var templatePath = _umgebung.CreateTemplate("AuflistungFarbe", "{{Schadensaufstellung}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListing
            {
                Items =
                [
                    new DamageItem { Description = "Reparaturkosten", Amount = 1000m },
                    new DamageItem { Description = "Wertminderung", Amount = 200m }
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
        var templatePath = _umgebung.CreateTemplate(
            "AuflistungKorrigiert",
            "{{Schadensaufstellung}}",
            "Gebühr: {{Geschaeftsgebuehr}} Auslagen: {{Auslagenpauschale}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListing
            {
                Items = [new DamageItem { Description = "Reparaturkosten", Amount = 1000m }],
                GeschaeftsgebuehrOverride = 150.00m,
                AuslagenpauschaleOverride = 25.00m
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("Gebühr: 150,00");
        output.Text.Should().Contain("Auslagen: 25,00");
    }

    /// <summary>
    /// Eine noch unbezifferte Position gehört ins Schreiben: Sie steht mit 0,00 € in
    /// der Tabelle und geht in die Zwischensumme ein, ohne sie zu verändern. Vorher
    /// kam sie nie bis hierher — die Modellvalidierung wies sie mit 400 ab.
    /// </summary>
    [Fact]
    public void GenerateReplacedDocument_WithZeroAmountItem_ShowsItInTheTable()
    {
        var templatePath = _umgebung.CreateTemplate("AuflistungNull", "{{Schadensaufstellung}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListing
            {
                Items =
                [
                    new DamageItem { Description = "Reparaturkosten netto nach Gutachten", Amount = 2560.87m },
                    new DamageItem { Description = "Sachverständigenkosten (Rechnung steht aus)", Amount = 0m }
                ]
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        var table = output.Tables.Should().ContainSingle().Subject;

        table.Rows[2].Cells[0].Paragraphs[0].Text.Should().Be("2");
        table.Rows[2].Cells[1].Paragraphs[0].Text.Should().Be("Sachverständigenkosten (Rechnung steht aus)");
        table.Rows[2].Cells[2].Paragraphs[0].Text.Should().Be("0,00");
        // Kopfzeile + 2 Positionen + Leerzeile + Zwischensumme + Anwaltskosten
        table.Rows[4].Cells[2].Paragraphs[0].Text.Should().Be("2.560,87");
    }

    /// <summary>
    /// Jede Zelle trägt ihre Absatzabstände **explizit** kompakt (kein Abstand
    /// davor/danach, einfacher Zeilenabstand) statt sie von der Vorlage zu
    /// erben. Der Grund: Mit neuerem Word angelegte Vorlagen bringen als
    /// Dokument-Standard 8 pt Abstand nach jedem Absatz und 1,08-fachen
    /// Zeilenabstand mit — jede Tabellenzeile war dann fast doppelt so hoch
    /// wie ihr Text, und dieselbe Aufstellung sah je nach Vorlage anders aus.
    /// Geprüft wird das XML, denn genau das entscheidet: Ein explizites
    /// w:spacing am Absatz schlägt die geerbten docDefaults immer.
    /// </summary>
    [Fact]
    public void GenerateReplacedDocument_SetztKompakteAbsatzabstaendeInJederZelle()
    {
        var templatePath = _umgebung.CreateTemplate("AuflistungKompakt", "{{Schadensaufstellung}}");

        var result = _umgebung.CreateService().GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = new DamageListing
            {
                Items = [new DamageItem { Description = "Reparaturkosten netto nach Gutachten", Amount = 2560.87m }]
            }
        });

        using var output = DocX.Load(result.OutputFilePath);
        var table = output.Tables.Should().ContainSingle().Subject;
        XNamespace w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";

        static void AttributSollSein(XElement spacing, XName name, string wert)
        {
            var attribut = spacing.Attribute(name);
            attribut.Should().NotBeNull("w:spacing muss {0} explizit setzen", name.LocalName);
            attribut!.Value.Should().Be(wert);
        }

        foreach (var row in table.Rows)
        {
            foreach (var cell in row.Cells)
            {
                foreach (var paragraph in cell.Paragraphs)
                {
                    var spacing = paragraph.Xml.Element(w + "pPr")?.Element(w + "spacing");
                    spacing.Should().NotBeNull(
                        "jeder Zellenabsatz muss seine Abstände selbst festlegen, "
                        + "sonst bestimmt die Vorlage die Zeilenhöhe");
                    AttributSollSein(spacing!, w + "before", "0");
                    AttributSollSein(spacing!, w + "after", "0");
                    AttributSollSein(spacing!, w + "line", "240");
                }
            }
        }
    }

    public void Dispose() => _umgebung.Dispose();
}
