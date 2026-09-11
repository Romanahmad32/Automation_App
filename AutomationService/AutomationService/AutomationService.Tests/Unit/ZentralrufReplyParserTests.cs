using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

public class ZentralrufReplyParserTests
{
    // Gekürzte, strukturgleiche Fassung von "Beispiele/Anwortemail von Zentralruf.txt".
    private const string BeispielMail = """
        Antwort von Zentralruf: Ihre Anfrage mit Zeichen 84/26 C03_GG-XY 123 vom 08.04.2026
        office@musterkanzlei.de <office@musterkanzlei.de>	8. April 2026 um 21:50
        An: "kanzlei@musterkanzlei.de" <kanzlei@musterkanzlei.de>
        An:
        Martin Mustermann
        Musterweg, 1
        60313 Frankfurt am Main
        office@musterkanzlei.de

        Ihre Anfrage vom 08.04.2026
        Ihr Zeichen: 84/26 C03_GG-XY 123
        Angefragtes Kennzeichen: GG XY 123
        Nationalitätskennzeichen: D

        Sehr geehrte Damen und Herren,

        zu dem Kennzeichen GG XY 123 konnte folgender Versicherer zum Unfalldatum 09.03.2026 ermittelt werden:

        HUK-COBURG
        Haftpflicht-Unterstützungs-Kasse
        kraftfahrender Beamter Deutschlands a.G
        Lyoner Str. 10
        60524 Frankfurt
        Tel.: 0800/248544533
        Fax: 0800-2485329
        E-Mail: info@huk-coburg.de
        Versicherungsschein-Nr.: 999/123456-X
        Versicherungsbeginn: 07.10.2015

        Unseren Auskünften liegen Daten zugrunde, die in regelmäßigen Abständen aktualisiert werden.

        Mit freundlichen Grüßen
        Ihr Zentralruf der Autoversicherer
        """;

    private readonly ZentralrufReplyParser _parser = new();

    [Fact]
    public void Parse_BeispielMail_ExtrahiertKopfdaten()
    {
        var data = _parser.Parse(BeispielMail);

        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.AnfrageDatum.Should().Be("08.04.2026");
        // Die Mail schreibt "GG XY 123", und so bleibt es: Die App bringt kein
        // Kennzeichen von sich aus in die Schreibweise mit Bindestrich (§4.2, #144).
        data.Kennzeichen.Should().Be("GG XY 123");
        data.UnfallDatum.Should().Be("09.03.2026");
        data.KeinVersichererErmittelt.Should().BeFalse();
    }

    [Fact]
    public void Parse_BeispielMail_ZerlegtReferenzInBestandteile()
    {
        var data = _parser.Parse(BeispielMail);

        data.ReferenzAuftragsnummer.Should().Be("84");
        data.ReferenzJahr.Should().Be("26");
        data.ReferenzAbteilung.Should().Be("C03");
        data.ReferenzKennzeichen.Should().Be("GG-XY 123");
    }

    /// <summary>
    /// Kein Umschreiben (§4.2, #144): Was in der Mail steht, kommt durch — nur
    /// der Leerraum wird vereinheitlicht, im angefragten Kennzeichen wie in der
    /// Referenz. Bis #144 machte der Parser aus <c>HGE1427</c> geraten
    /// <c>HG-E 1427</c> und benannte damit womöglich ein anderes Fahrzeug.
    /// </summary>
    [Theory]
    [InlineData("GG XY 123", "GG XY 123")]
    [InlineData("gg xy 123", "gg xy 123")]
    [InlineData("HGE1427", "HGE1427")]
    [InlineData("HG-E 1427", "HG-E 1427")]
    [InlineData("123 ABC", "123 ABC")]
    [InlineData("UNBEKANNT  123 456", "UNBEKANNT 123 456")]
    public void Parse_UebernimmtKennzeichenWieInDerMail(string roh, string erwartet)
    {
        var data = _parser.Parse($"Ihr Zeichen: 84/26 C03_{roh}\nAngefragtes Kennzeichen: {roh}\n");

        data.Kennzeichen.Should().Be(erwartet);
        data.ReferenzKennzeichen.Should().Be(erwartet);
    }

    [Fact]
    public void Parse_NegativAntwort_SetztKeinVersichererErmittelt()
    {
        const string negativMail = """
            Ihre Anfrage vom 08.04.2026
            Ihr Zeichen: 84/26 C03_GG-XY 123
            Angefragtes Kennzeichen: GG XY 123

            Sehr geehrte Damen und Herren,

            zu dem Kennzeichen GG XY 123 konnte leider kein Versicherer zum Unfalldatum 09.03.2026 ermittelt werden.

            Mit freundlichen Grüßen
            Ihr Zentralruf der Autoversicherer
            """;

        var data = _parser.Parse(negativMail);

        data.KeinVersichererErmittelt.Should().BeTrue();
        data.VersichererName.Should().BeNull();
        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.Kennzeichen.Should().Be("GG XY 123");
    }

    [Fact]
    public void Parse_BeispielMail_ExtrahiertVersichererBlock()
    {
        var data = _parser.Parse(BeispielMail);

        data.VersichererName.Should().Be("HUK-COBURG Haftpflicht-Unterstützungs-Kasse kraftfahrender Beamter Deutschlands a.G");
        data.VersichererStrasse.Should().Be("Lyoner Str. 10");
        data.VersichererPlz.Should().Be("60524");
        data.VersichererOrt.Should().Be("Frankfurt");
        data.VersichererTelefon.Should().Be("0800/248544533");
        data.VersichererFax.Should().Be("0800-2485329");
        data.VersichererEmail.Should().Be("info@huk-coburg.de");
        data.VersicherungsscheinNr.Should().Be("999/123456-X");
        data.Versicherungsbeginn.Should().Be("07.10.2015");
    }

    [Fact]
    public void Parse_HtmlText_MitLeerzeileZwischenJederZeile_ExtrahiertVersichererBlock()
    {
        // Aus HTML gewonnener Text (ZentralrufReplyEmailExtractor.HtmlToPlainText)
        // enthält oft eine Leerzeile zwischen jeder Absatzzeile. Der Block darf
        // dann nicht schon nach der ersten Zeile abbrechen.
        var htmlAehnlich = BeispielMail.Replace("\n", "\n\n");

        var data = _parser.Parse(htmlAehnlich);

        data.VersichererName.Should().Be("HUK-COBURG Haftpflicht-Unterstützungs-Kasse kraftfahrender Beamter Deutschlands a.G");
        data.VersichererStrasse.Should().Be("Lyoner Str. 10");
        data.VersichererPlz.Should().Be("60524");
        data.VersichererOrt.Should().Be("Frankfurt");
        data.VersichererTelefon.Should().Be("0800/248544533");
        data.VersichererFax.Should().Be("0800-2485329");
        data.VersichererEmail.Should().Be("info@huk-coburg.de");
        data.VersicherungsscheinNr.Should().Be("999/123456-X");
        data.Versicherungsbeginn.Should().Be("07.10.2015");
    }

    [Fact]
    public void Parse_MitWindowsZeilenenden_ExtrahiertVersichererBlock()
    {
        var data = _parser.Parse(BeispielMail.Replace("\n", "\r\n"));

        data.VersicherungsscheinNr.Should().Be("999/123456-X");
        data.VersichererStrasse.Should().Be("Lyoner Str. 10");
    }

    [Fact]
    public void Parse_FremderText_LiefertKeineWerte()
    {
        var data = _parser.Parse("Hallo, dies ist keine Zentralruf-Antwort.");

        data.Referenz.Should().BeNull();
        data.Kennzeichen.Should().BeNull();
        data.UnfallDatum.Should().BeNull();
        data.VersichererName.Should().BeNull();
        data.VersicherungsscheinNr.Should().BeNull();
    }

    [Fact]
    public void Parse_EchteBeispieldatei_WennVorhanden_ExtrahiertKerndaten()
    {
        // Läuft gegen die echte Beispieldatei, sofern das Repo-Layout sie hergibt.
        var path = Path.Combine(
            AppContext.BaseDirectory,
            "..", "..", "..", "..", "..", "..", "Beispiele", "Anwortemail von Zentralruf.txt");
        if (!File.Exists(path))
        {
            return;
        }

        var data = _parser.Parse(File.ReadAllText(path));

        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.Kennzeichen.Should().Be("GG XY 123");
        data.UnfallDatum.Should().Be("09.03.2026");
        data.VersicherungsscheinNr.Should().Be("999/123456-X");
        data.VersichererEmail.Should().Be("info@huk-coburg.de");
    }
}
