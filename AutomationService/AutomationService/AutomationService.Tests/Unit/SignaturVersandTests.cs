using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Tests.Support;
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

    private string Datei(string name, byte[] inhalt) =>
        SignaturProben.Datei(_ordner, name, inhalt);

    private static byte[] Bild(int bytes) => SignaturProben.Bild(bytes);

    private static EmailNachricht Nachricht(string text = "Sehr geehrte Damen und Herren,") =>
        new(["gegner@example.de"], [], "Anspruchsschreiben", text, [], "Kanzlei Ahmad");

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

    /// <summary>
    /// Das animierte Werbebild ist der Anlass des ganzen Abwählens (§4.7) — es
    /// muss also erst einmal heil hinausgehen.
    ///
    /// Geprüft wird, was über „sieht gut aus" hinausgeht: dass die Bytes
    /// <b>unverändert</b> ankommen (jede Umkodierung wäre das Ende der
    /// Animation) und dass der Teil als <c>image/gif</c> ausgewiesen ist. Ohne
    /// die richtige Inhaltsart zeigt manches Programm einen Anhang statt eines
    /// Bildes.
    /// </summary>
    [Fact]
    public void MailRumpf_SchicktEinAnimiertesGifUnveraendert()
    {
        var bytes = SignaturProben.AnimiertesGif();
        var werbung = Datei("werbung.gif", bytes);
        var signatur = new SignaturVersand(
            "Kanzlei Ahmad",
            "<p>Kanzlei Ahmad</p><img src=\"werbung.gif\">",
            [werbung]);

        var mime = EmailNachrichtBauer.Baue(Nachricht(), "kanzlei@example.de", [], signatur);

        var eingebettet = mime.BodyParts.OfType<MimePart>()
            .Single(teil => teil.ContentId is not null);
        eingebettet.ContentType.MimeType.Should().Be("image/gif");

        using var strom = new MemoryStream();
        eingebettet.Content.Should().NotBeNull();
        eingebettet.Content!.DecodeTo(strom);
        strom.ToArray().Should().Equal(bytes);
        mime.HtmlBody.Should().Contain($"cid:{eingebettet.ContentId}");
    }

    public void Dispose()
    {
        if (Directory.Exists(_ordner))
        {
            Directory.Delete(_ordner, recursive: true);
        }
    }
}
