using System.Globalization;
using System.IO.Compression;
using System.Text.RegularExpressions;
using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die erzeugte Word-Datei am OOXML statt am Augenschein (§6.2, #40).
///
/// Die Zusicherungen sind die Gegenprobe zu dem, was in der gewachsenen
/// Kanzleidatei vermessen wurde: Sie hat keine wiederholte Kopfzeile, keine
/// Rahmen, einen Schriftbruch zwischen Kopf und Körper und eine Tabelle, die
/// über den rechten Rand ragt. Genau das soll hier nicht herauskommen — und ein
/// Augenschein würde eine zurückgefallene Einstellung nie bemerken.
/// </summary>
public sealed class RegisterDokumentTests : IDisposable
{
    readonly string _ordner = Directory.CreateTempSubdirectory("register-dokument").FullName;

    /// <summary>Satzspiegel bei A4 hoch mit 2,5 cm Rand, in Twips.</summary>
    const int SatzspiegelTwips = 9072;

    static readonly RegisterZeile[] ZweiJahrgaenge =
    [
        new("2025", 1, "01/25 C03", "Daniel Mustermann ./. HUK", "Sachverhalt v. 19.11.2024",
            "Verkehrsrecht", true),
        new("2026", 1, "01/26 C03", "Sonja Musterfrau ./. HUK24", "Sachverhalt v. 28.12.2025",
            "Verkehrsrecht", true),
        new("2026", null, "05/26 C03o", "Michael Mustermann ./. ", "", "Verkehrsstrafrecht", false),
    ];

    string Schreibe(IReadOnlyList<RegisterZeile> zeilen, bool nurAbgeschlossene = false)
    {
        var pfad = Path.Combine(_ordner, $"{Guid.NewGuid():N}.docx");
        RegisterDokument.Schreibe(pfad, zeilen, new DateTime(2026, 8, 30, 12, 0, 0), nurAbgeschlossene);
        return pfad;
    }

    static string Xml(string docx)
    {
        using var archiv = ZipFile.OpenRead(docx);
        using var strom = archiv.GetEntry("word/document.xml")!.Open();
        using var leser = new StreamReader(strom);
        return leser.ReadToEnd();
    }

    [Fact]
    public void Schreibe_ErzeugtDieVierSpaltenDesSchemas()
    {
        var breiten = Regex.Matches(Xml(Schreibe(ZweiJahrgaenge)), @"<w:gridCol w:w=""(\d+)""")
            .Select(t => int.Parse(t.Groups[1].Value, CultureInfo.InvariantCulture))
            .ToList();

        breiten.Should().Equal(RegisterLayout.SpaltenbreitenTwips);
        breiten.Sum().Should().BeLessThanOrEqualTo(
            SatzspiegelTwips,
            "die Tabelle der Vorlagendatei ragt über den rechten Rand — der Export soll das nicht erben");
    }

    [Fact]
    public void Schreibe_WiederholtDieKopfzeileAufJederSeite()
    {
        Xml(Schreibe(ZweiJahrgaenge)).Should().Contain(
            "<w:tblHeader",
            "der Vorlagendatei fehlt das, und ab Seite 2 muss man die Spalten raten");
    }

    [Fact]
    public void Schreibe_ZiehtRahmenUmDieTabelle()
    {
        Xml(Schreibe(ZweiJahrgaenge)).Should().Contain("tblBorders");
    }

    [Fact]
    public void Schreibe_SetztAllesInDieSchriftDerKanzlei()
    {
        var xml = Xml(Schreibe(ZweiJahrgaenge));

        xml.Should().Contain(RegisterLayout.Schriftart);
        Regex.Matches(xml, @"w:ascii=""([^""]+)""")
            .Select(t => t.Groups[1].Value)
            .Distinct()
            .Should().ContainSingle(
                "in der Vorlagendatei steht die Kopfzeile in Times New Roman und der Körper in Century Gothic")
            .Which.Should().Be(RegisterLayout.Schriftart);
    }

    [Fact]
    public void Schreibe_SetztJeJahrgangEineZwischenueberschrift()
    {
        var xml = Xml(Schreibe(ZweiJahrgaenge));

        Zeilentexte(xml).Should().ContainInOrder("2025", "2026");
        Regex.Matches(xml, @"<w:gridSpan w:val=""4""").Should().HaveCount(
            2, "jede Jahreszeile geht über die volle Breite");
    }

    /// <summary>
    /// Die Jahreszeilen tragen eine Überschriften-Formatvorlage. Daraus baut
    /// Word beim PDF-Export die Sprungmarken — auf dem Handy der Unterschied
    /// zwischen „zum Jahrgang springen" und „durch 90 Seiten wischen".
    /// </summary>
    [Fact]
    public void Schreibe_MachtAusJahreszeilenSprungmarkenFuerDasPdf()
    {
        Regex.Matches(Xml(Schreibe(ZweiJahrgaenge)), @"<w:pStyle w:val=""Heading2""")
            .Should().HaveCount(2);
    }

    [Fact]
    public void Schreibe_ZeichnetNichtAbgeschlosseneZeilenAus()
    {
        var xml = Xml(Schreibe(ZweiJahrgaenge));

        xml.Should().Contain("<w:i>", "offene Zeilen stehen kursiv");
        xml.Should().Contain(RegisterLayout.Legende, "und die Kursivstellung wird erklärt");
    }

    [Fact]
    public void Schreibe_LaesstDieLegendeWeg_WennAllesAbgeschlossenIst()
    {
        var nurFertige = ZweiJahrgaenge.Where(z => z.Abgeschlossen).ToList();

        Xml(Schreibe(nurFertige, nurAbgeschlossene: true)).Should().NotContain(RegisterLayout.Legende);
    }

    /// <summary>
    /// Der Satz ist der einzige Schutz gegen die zwei Originale, der auf jedem
    /// Gerät ankommt — auf dem Handy, im Web, im Ausdruck.
    /// </summary>
    [Fact]
    public void Schreibe_WeistDieDateiAlsSpiegelAus()
    {
        Xml(Schreibe(ZweiJahrgaenge)).Should().Contain(RegisterLayout.Spiegelhinweis);
    }

    [Fact]
    public void Schreibe_KommtOhneVorgaengeAus()
    {
        var xml = Xml(Schreibe([]));

        xml.Should().Contain("Noch keine Vorgänge erfasst.");
        xml.Should().NotContain("<w:tbl>");
    }

    static IEnumerable<string> Zeilentexte(string xml) =>
        Regex.Matches(xml, @"<w:tr[ >].*?</w:tr>", RegexOptions.Singleline)
            .Select(zeile => string.Concat(
                Regex.Matches(zeile.Value, @"<w:t[^>]*>([^<]*)</w:t>").Select(t => t.Groups[1].Value)));

    public void Dispose() => Directory.Delete(_ordner, recursive: true);
}
