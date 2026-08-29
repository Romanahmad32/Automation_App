using System.Xml.Linq;
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

    /// <summary>
    /// Legt eine .docx an, deren Absätze mit echten Word-Kontrollkästchen
    /// beginnen — Inhaltssteuerelement &lt;w:sdt&gt; mit &lt;w14:checkbox&gt;,
    /// die zweite Schreibweise der Kanzlei-Vorlagen. Dort stehen Zustand
    /// (&lt;w14:checked&gt;) und angezeigtes Glyph getrennt, und genau dieses
    /// Paar muss <see cref="VorsteuerCheckbox"/> zusammen umstellen.
    ///
    /// Gebaut statt geladen: Zuvor holte sich der Test die echte Vorlage aus
    /// <c>Beispiele/</c> und sprang still zurück, wenn sie fehlte — in der CI
    /// und in jedem frischen Klon also immer. Er meldete grün für eine
    /// Prüfung, die nie gelaufen war. <c>DocX</c> selbst kann keine
    /// Inhaltssteuerelemente erzeugen, deshalb wird das XML hier eingehängt.
    /// </summary>
    public string CreateTemplateWithWordCheckboxes(
        string name,
        params (string Text, bool Checked)[] paragraphs)
    {
        ArgumentNullException.ThrowIfNull(paragraphs);

        var path = Path.Combine(_contentRoot, "Templates", $"{name}.docx");
        using var document = DocX.Create(path);
        foreach (var (text, isChecked) in paragraphs)
        {
            var paragraph = document.InsertParagraph(text);
            paragraph.Xml.AddFirst(CheckboxSteuerelement(isChecked));
        }
        document.Save();
        return path;
    }

    private static readonly XNamespace W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
    private static readonly XNamespace W14 = "http://schemas.microsoft.com/office/word/2010/wordml";

    /// <summary>Ein Kontrollkästchen, wie Word es schreibt: Zustand im
    /// &lt;w14:checked&gt;-Attribut, sichtbares Glyph als Text darunter.</summary>
    private static XElement CheckboxSteuerelement(bool isChecked) =>
        new(W + "sdt",
            new XAttribute(XNamespace.Xmlns + "w14", W14.NamespaceName),
            new XElement(W + "sdtPr",
                new XElement(W14 + "checkbox",
                    new XElement(W14 + "checked", new XAttribute(W14 + "val", isChecked ? "1" : "0")),
                    new XElement(W14 + "checkedState",
                        new XAttribute(W14 + "val", "2612"), new XAttribute(W14 + "font", "MS Gothic")),
                    new XElement(W14 + "uncheckedState",
                        new XAttribute(W14 + "val", "2610"), new XAttribute(W14 + "font", "MS Gothic")))),
            new XElement(W + "sdtContent",
                new XElement(W + "r",
                    new XElement(W + "t", isChecked ? "☒" : "☐"))));

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
