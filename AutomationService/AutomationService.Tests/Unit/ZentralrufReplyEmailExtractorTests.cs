using System.Text;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

public class ZentralrufReplyEmailExtractorTests
{
    // Minimale .eml-Datei mit Quoted-Printable-Body, wie sie Gmail/Outlook
    // beim Speichern einer Nachricht erzeugen ("ü" wird zu "=C3=BC").
    private const string QuotedPrintableEml = """
        From: Zentralruf <noreply@gdv-dl.de>
        To: office@musterkanzlei.de
        Subject: Antwort von Zentralruf: Ihre Anfrage mit Zeichen 84/26 C03_GG-XY 123 vom 08.04.2026
        MIME-Version: 1.0
        Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: quoted-printable

        Ihr Zeichen: 84/26 C03_GG-XY 123
        Angefragtes Kennzeichen: GG XY 123

        zu dem Kennzeichen GG XY 123 konnte folgender Versicherer zum Unfalldatum 09.03.2026 ermittelt werden:

        HUK-COBURG
        Lyoner Str. 10
        60524 Frankfurt
        Versicherungsschein-Nr.: 999/123456-X

        Mit freundlichen Gr=C3=BC=C3=9Fen
        """;

    [Fact]
    public void ExtractText_KlartextOhneEml_GibtTextUnveraendertZurueck()
    {
        const string text = "Ihr Zeichen: 84/26 C03_GG-XY 123";

        ZentralrufReplyEmailExtractor.ExtractText(text, null).Should().Be(text);
    }

    [Fact]
    public void ExtractText_QuotedPrintableEml_DekodiertBodyUndStelltBetreffVoran()
    {
        var base64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(QuotedPrintableEml));

        var text = ZentralrufReplyEmailExtractor.ExtractText(null, base64);

        text.Should().StartWith("Antwort von Zentralruf: Ihre Anfrage mit Zeichen 84/26 C03_GG-XY 123 vom 08.04.2026");
        text.Should().Contain("Mit freundlichen Grüßen");
        text.Should().Contain("Versicherungsschein-Nr.: 999/123456-X");
        text.Should().NotContain("=C3=BC");
    }

    [Fact]
    public void ExtractText_QuotedPrintableEml_ErgebnisIstParsebar()
    {
        var base64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(QuotedPrintableEml));
        var text = ZentralrufReplyEmailExtractor.ExtractText(null, base64);

        var data = new ZentralrufReplyParser().Parse(text);

        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.Kennzeichen.Should().Be("GG-XY 123");
        data.VersichererName.Should().Be("HUK-COBURG");
        data.VersicherungsscheinNr.Should().Be("999/123456-X");
    }

    [Fact]
    public void ExtractText_HtmlBody_WirdZuLesbaremText()
    {
        const string htmlEml = """
            From: Zentralruf <noreply@gdv-dl.de>
            Subject: Antwort von Zentralruf
            MIME-Version: 1.0
            Content-Type: text/html; charset=utf-8

            <html><body>
            <p>Ihr Zeichen: 84/26 C03_GG-XY 123</p>
            <p>zu dem Kennzeichen GG XY 123 konnte folgender Versicherer zum Unfalldatum 09.03.2026 ermittelt werden:</p>
            <p>HUK-COBURG<br>Lyoner Str. 10<br>60524 Frankfurt<br>Versicherungsschein-Nr.: 999/123456-X</p>
            </body></html>
            """;
        var base64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(htmlEml));

        var text = ZentralrufReplyEmailExtractor.ExtractText(null, base64);
        var data = new ZentralrufReplyParser().Parse(text);

        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.VersichererStrasse.Should().Be("Lyoner Str. 10");
        data.VersichererPlz.Should().Be("60524");
    }

    [Fact]
    public void ExtractText_UngueltigesBase64_WirftFormatException()
    {
        var act = () => ZentralrufReplyEmailExtractor.ExtractText(null, "kein-base64!!");

        act.Should().Throw<FormatException>();
    }

    [Fact]
    public void ExtractFromMessage_GeladeneNachricht_LiefertParsebarenText()
    {
        // Weg des Postfach-Monitors: er hat die Nachricht bereits per IMAP
        // geladen und gibt die MimeMessage direkt in den Extractor.
        using var stream = new MemoryStream(Encoding.UTF8.GetBytes(QuotedPrintableEml));
        var message = MimeKit.MimeMessage.Load(stream);

        var text = ZentralrufReplyEmailExtractor.ExtractFromMessage(message);
        var data = new ZentralrufReplyParser().Parse(text);

        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
        data.VersichererName.Should().Be("HUK-COBURG");
        data.VersicherungsscheinNr.Should().Be("999/123456-X");
    }
}
