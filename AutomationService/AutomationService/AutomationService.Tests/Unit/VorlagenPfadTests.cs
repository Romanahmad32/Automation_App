using AutomationService.Features.FormTemplates.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Kern von #33: Vorlagenpfade werden relativ zum eingestellten Ordner
/// gespeichert, damit dieselbe Datenbank auf zwei Rechnern mit verschiedenen
/// Ordnern funktioniert — und der Altbestand mit absoluten Pfaden bleibt
/// dabei lesbar.
/// </summary>
public sealed class VorlagenPfadTests
{
    [Fact]
    public void MacheRelativ_KuerztEinenPfadImOrdnerAufDenRest()
    {
        VorlagenPfad.MacheRelativ(@"C:\Kanzlei\Vorlagen", @"C:\Kanzlei\Vorlagen\Anspruch.docx")
            .Should().Be("Anspruch.docx");
        VorlagenPfad.MacheRelativ(@"C:\Kanzlei\Vorlagen", @"C:\Kanzlei\Vorlagen\Unfall\Anspruch.docx")
            .Should().Be(@"Unfall\Anspruch.docx");
    }

    [Fact]
    public void MacheRelativ_LaesstAussenliegendeUndLeerePfadeUnveraendert()
    {
        VorlagenPfad.MacheRelativ(@"C:\Kanzlei\Vorlagen", @"C:\Woanders\Anspruch.docx")
            .Should().Be(@"C:\Woanders\Anspruch.docx");
        VorlagenPfad.MacheRelativ(@"C:\Kanzlei\Vorlagen", null).Should().BeNull();
        VorlagenPfad.MacheRelativ(@"C:\Kanzlei\Vorlagen", "").Should().Be("");
    }

    /// <summary>
    /// C:\VorlagenAlt beginnt mit der Zeichenkette C:\Vorlagen, liegt aber
    /// nicht darin — der Trenner am Ende der Wurzel muss das verhindern.
    /// </summary>
    [Fact]
    public void MacheRelativ_FaelltNichtAufDenNamensPraefixHerein()
    {
        VorlagenPfad.MacheRelativ(@"C:\Vorlagen", @"C:\VorlagenAlt\Anspruch.docx")
            .Should().Be(@"C:\VorlagenAlt\Anspruch.docx");
    }

    /// <summary>
    /// Die eigentliche Zusage: derselbe gespeicherte Rest ergibt gegen zwei
    /// verschiedene Ordner jeweils die richtige Datei — Kanzlei-PC und
    /// Heim-Laptop koennen verschiedene Pfade haben.
    /// </summary>
    [Fact]
    public void LoeseAuf_DerselbeRestTrifftInZweiOrdnernDieRichtigeDatei()
    {
        VorlagenPfad.LoeseAuf(@"C:\Kanzlei\Vorlagen", @"Unfall\Anspruch.docx")
            .Should().Be(@"C:\Kanzlei\Vorlagen\Unfall\Anspruch.docx");
        VorlagenPfad.LoeseAuf(@"D:\OneDrive\Vorlagen", @"Unfall\Anspruch.docx")
            .Should().Be(@"D:\OneDrive\Vorlagen\Unfall\Anspruch.docx");
    }

    [Fact]
    public void LoeseAuf_LaesstAbsolutenAltbestandUndLeeresUnveraendert()
    {
        VorlagenPfad.LoeseAuf(@"C:\Kanzlei\Vorlagen", @"C:\Woanders\Anspruch.docx")
            .Should().Be(@"C:\Woanders\Anspruch.docx");
        VorlagenPfad.LoeseAuf(@"C:\Kanzlei\Vorlagen", null).Should().BeNull();
        VorlagenPfad.LoeseAuf(@"C:\Kanzlei\Vorlagen", "").Should().Be("");
    }

    [Fact]
    public void HinUndZurueck_ErgibtWiederDenAusgangspfad()
    {
        const string ordner = @"C:\Kanzlei\Vorlagen";
        const string original = @"C:\Kanzlei\Vorlagen\Anspruch.docx";
        var gespeichert = VorlagenPfad.MacheRelativ(ordner, original);
        VorlagenPfad.LoeseAuf(ordner, gespeichert).Should().Be(original);
    }
}
