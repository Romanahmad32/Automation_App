using AutomationService.Features.WordAutomation.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Schutzwall vor dem Dateinamen (§4.9, #32). Gebaut wird der Name im
/// Frontend; hier wird nur noch dafür gesorgt, dass daraus ein gültiger
/// Windows-Dateiname wird — und zwar ohne dabei still etwas wegzuschneiden.
/// </summary>
public sealed class OutputFileNamingTests
{
    [Fact]
    public void Name_AusDemFrontend_BleibtErhalten()
    {
        OutputFileNaming.BuildFileName(
                "Anspruchsschreiben an Allianz 1 Vorfahrtverletzung STOP 205",
                "VORLAGE HGN")
            .Should().Be("Anspruchsschreiben an Allianz 1 Vorfahrtverletzung STOP 205.docx");
    }

    /// <summary>
    /// Der Versicherername stammt aus einer Zentralruf-Antwort und ist nicht in
    /// der Hand der Kanzlei. Entscheidend ist, dass nichts <em>verschwindet</em>:
    /// Das frühere <c>Path.GetFileName</c> hätte hier alles vor dem Schrägstrich
    /// abgeschnitten und wortlos "DBV 1 Vorlage.docx" geliefert.
    /// </summary>
    [Theory]
    [InlineData("Anspruchsschreiben an AXA/DBV 1 Vorlage",
                "Anspruchsschreiben an AXA-DBV 1 Vorlage.docx")]
    [InlineData("Anspruchsschreiben an HUK: Coburg 1 Vorlage",
                "Anspruchsschreiben an HUK- Coburg 1 Vorlage.docx")]
    [InlineData(@"Anspruchsschreiben an R+V\Direkt 1 Vorlage",
                "Anspruchsschreiben an R+V-Direkt 1 Vorlage.docx")]
    public void UnzulaessigeZeichen_WerdenErsetztStattAbgeschnitten(
        string gewuenscht, string erwartet)
    {
        OutputFileNaming.BuildFileName(gewuenscht, "VORLAGE HGN")
            .Should().Be(erwartet);
    }

    /// <summary>
    /// Kaufmännisches Und ist unter Windows erlaubt — "Rhion &amp; Co" soll auch
    /// so heißen.
    /// </summary>
    [Fact]
    public void KaufmaennischesUnd_BleibtStehen()
    {
        OutputFileNaming.BuildFileName("Anspruchsschreiben an Rhion & Co 1 Vorlage", "V")
            .Should().Be("Anspruchsschreiben an Rhion & Co 1 Vorlage.docx");
    }

    /// <summary>
    /// Ein Name, der nur aus unzulässigen Zeichen bestünde, darf keinen
    /// Verzeichniswechsel überleben: Der Ersatz macht daraus Bindestriche, nicht
    /// einen Pfad.
    /// </summary>
    [Fact]
    public void Pfadwechsel_IstNichtMoeglich()
    {
        var name = OutputFileNaming.BuildFileName(@"..\..\Windows\System32\böse", "V");
        name.Should().Be("..-..-Windows-System32-böse.docx");
        name.Should().NotContain("/").And.NotContain(@"\");
    }

    [Theory]
    [InlineData("Anspruchsschreiben an Allianz 1 Vorlage.docx")]
    [InlineData("Anspruchsschreiben an Allianz 1 Vorlage.DOCX")]
    [InlineData("Anspruchsschreiben an Allianz 1 Vorlage.doc")]
    public void AngehaengteEndung_WirdNichtVerdoppelt(string gewuenscht)
    {
        OutputFileNaming.BuildFileName(gewuenscht, "V")
            .Should().Be("Anspruchsschreiben an Allianz 1 Vorlage.docx");
    }

    /// <summary>
    /// Punkte mitten im Namen bleiben — ein Datum "12.05.2025" ist keine Endung.
    /// </summary>
    [Fact]
    public void PunkteImNamen_BleibenErhalten()
    {
        OutputFileNaming.BuildFileName("Anspruchsschreiben an Allianz 1 Unfall 12.05.2025", "V")
            .Should().Be("Anspruchsschreiben an Allianz 1 Unfall 12.05.2025.docx");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("  ...  ")]
    public void OhneBrauchbarenNamen_GreiftDerRueckfall(string gewuenscht)
    {
        OutputFileNaming.BuildFileName(gewuenscht, "VORLAGE HGN")
            .Should().StartWith("VORLAGE HGN_")
            .And.EndWith(".docx");
    }
}
