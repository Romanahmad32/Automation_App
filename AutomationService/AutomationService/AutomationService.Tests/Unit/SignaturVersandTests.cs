using System.Text;
using AutomationService.Features.EmailVersand.Domain.Services;
using FluentAssertions;
using MimeKit;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die formatierte Signatur (§4.7): Schrift, Farben und Logo der Kanzlei sollen
/// beim Empfänger ankommen — aber nicht das schwere Werbebild unter jeder Mail.
///
/// Der teuerste Fehler wäre still: eine Signatur, die beim Empfänger als
/// Platzhalterkreuz erscheint, weil das Bild zwar erwähnt, aber nicht
/// mitgeschickt wurde. Deshalb wird hier die fertige MIME-Nachricht geprüft und
/// nicht nur die Zwischenschritte.
/// </summary>
public sealed class SignaturVersandTests : IDisposable
{
    private readonly string _ordner =
        Path.Combine(Path.GetTempPath(), $"SignaturTests_{Guid.NewGuid():N}");

    public SignaturVersandTests() => Directory.CreateDirectory(_ordner);

    private string Datei(string name, byte[] inhalt)
    {
        var pfad = Path.Combine(_ordner, name);
        Directory.CreateDirectory(Path.GetDirectoryName(pfad)!);
        File.WriteAllBytes(pfad, inhalt);
        return pfad;
    }

    private static byte[] Bild(int bytes) => Enumerable.Repeat((byte)7, bytes).ToArray();

    private static EmailNachricht Nachricht(string text = "Sehr geehrte Damen und Herren,") =>
        new(["gegner@example.de"], [], "Anspruchsschreiben", text, [], "Kanzlei Ahmad");

    [Fact]
    public void OutlookSignaturHtml_SchneidetDenRumpfUndSammeltDieBilder()
    {
        Datei("Kanzlei-Dateien/logo.png", Bild(120));
        var htm = Datei("Kanzlei.htm", Encoding.UTF8.GetBytes(
            "<html><head><style>p{color:red}</style></head><body>"
            + "<p>Mit freundlichen Gr&uuml;&szlig;en</p>"
            + "<img src=\"Kanzlei-Dateien/logo.png\" width=\"120\">"
            + "</body></html>"));

        var gelesen = OutlookSignaturHtml.Lies(htm);

        gelesen.Should().NotBeNull();
        // Der Kopfbereich bleibt draussen: Outlooks Stilvorlage wuerde sonst
        // den Mailtext mitformatieren.
        gelesen!.Value.Html.Should().NotContain("<style>").And.Contain("Gr&uuml;&szlig;en");
        // Der Verweis ist auf den blanken Dateinamen gekuerzt -- der Beiordner
        // des Absenders existiert beim Empfaenger nicht.
        gelesen.Value.Html.Should().Contain("src=\"logo.png\"");
        gelesen.Value.Bilder.Should().ContainKey("logo.png");
    }

    [Fact]
    public void OutlookSignaturHtml_LaesstVerweiseInsNetzStehen()
    {
        var htm = Datei("Web.htm", Encoding.UTF8.GetBytes(
            "<body><img src=\"https://kanzlei.example.de/logo.png\"></body>"));

        var gelesen = OutlookSignaturHtml.Lies(htm);

        gelesen!.Value.Html.Should().Contain("https://kanzlei.example.de/logo.png");
        gelesen.Value.Bilder.Should().BeEmpty();
    }

    [Fact]
    public void SignaturHtmlFilter_NimmtDieGanzeBildmarkeHeraus()
    {
        const string html = "<p>Gruss</p><img src=\"logo.png\"><img src=\"werbung.gif\" alt=\"x\">";

        var uebrig = SignaturHtmlFilter.Ohne(html, new HashSet<string> { "werbung.gif" });

        uebrig.Should().Contain("logo.png");
        // Nicht nur die Quelle: Ein img ohne src zeigt beim Empfaenger ein
        // Platzhalterkreuz und saehe nach einem Fehler aus.
        uebrig.Should().NotContain("werbung.gif").And.NotContain("alt=\"x\"");
    }

    [Fact]
    public void SignaturHtmlFilter_MeldetNurDieNochVerwendetenBilder()
    {
        const string html = "<img src=\"logo.png\">";
        SignaturBild[] abgelegt = [new("logo.png", 100), new("werbung.gif", 4_000_000)];

        SignaturHtmlFilter.Verwendete(html, abgelegt).Should().Equal("logo.png");
    }

    [Fact]
    public void MailRumpf_OhneFormatierteSignatur_BleibtEsBeiReinemText()
    {
        var signatur = new SignaturVersand("Kanzlei Ahmad", string.Empty, []);

        var mime = EmailNachrichtBauer.Baue(Nachricht(), "kanzlei@example.de", [], signatur);

        mime.HtmlBody.Should().BeNull();
        mime.TextBody.Should().Contain("Sehr geehrte").And.Contain("Kanzlei Ahmad");
    }

    [Fact]
    public void MailRumpf_MitBild_SchicktEsMitUndVerweistUeberCid()
    {
        var logo = Datei("logo.png", Bild(200));
        var signatur = new SignaturVersand(
            "Kanzlei Ahmad",
            "<p>Kanzlei Ahmad</p><img src=\"logo.png\">",
            [logo]);

        var mime = EmailNachrichtBauer.Baue(Nachricht(), "kanzlei@example.de", [], signatur);

        // Der Dateiname ist verschwunden, an seiner Stelle steht die Content-Id
        // des mitgeschickten Teils.
        mime.HtmlBody.Should().NotBeNull().And.Contain("cid:").And.NotContain("src=\"logo.png\"");
        var eingebettet = mime.BodyParts.OfType<MimePart>()
            .Where(teil => teil.ContentId is not null)
            .ToList();
        eingebettet.Should().HaveCount(1);
        mime.HtmlBody.Should().Contain($"cid:{eingebettet[0].ContentId}");

        // Die Nur-Text-Fassung geht als Alternative mit: Wer kein HTML anzeigt,
        // soll kein Markup lesen muessen.
        mime.TextBody.Should().Contain("Sehr geehrte").And.Contain("Kanzlei Ahmad");
    }

    [Fact]
    public void MailRumpf_MaskiertDenGetipptenText()
    {
        var nachricht = Nachricht("Frist < 14 Tage & \"eilig\"");
        var signatur = new SignaturVersand("Kanzlei", "<p>Kanzlei</p>", []);

        var mime = EmailNachrichtBauer.Baue(nachricht, "kanzlei@example.de", [], signatur);

        mime.HtmlBody.Should().Contain("Frist &lt; 14 Tage &amp;");
        mime.TextBody.Should().Contain("Frist < 14 Tage & \"eilig\"");
    }

    [Fact]
    public void AnhangPruefung_SignaturbilderZaehlenZurGrenze()
    {
        var anhang = Datei("Anspruchsschreiben.pdf", Bild(600_000));

        // Der Anhang allein passt in ein Megabyte, mit dem Werbebild nicht mehr.
        var act = () => AnhangPruefung.Lade([anhang], maxGesamtMb: 1, zusatzBytes: 600_000);

        act.Should().Throw<EmailVersandException>()
            .Which.Message.Should().Contain("Signatur");
    }

    public void Dispose()
    {
        if (Directory.Exists(_ordner))
        {
            Directory.Delete(_ordner, recursive: true);
        }
    }
}
