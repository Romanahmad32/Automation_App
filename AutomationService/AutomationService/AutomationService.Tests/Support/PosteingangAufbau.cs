using MailKit;
using MimeKit;

namespace AutomationService.Tests.Support;

/// <summary>
/// Baut die Nachrichtenstruktur und den Umschlag, wie ein IMAP-Server sie
/// liefert — die Vorlage für jeden Posteingangstest.
///
/// MimeKit hat die Setter der <c>BodyPart</c>-Klassen als veraltet markiert:
/// Im Betrieb baut der Client diese Struktur beim Abruf, nicht der Aufrufer.
/// Genau das ist hier aber der Testaufbau — ohne von Hand gebaute Struktur gibt
/// es keine Prüfung der Zusage „welche Teile darf der Posteingang holen". Die
/// Unterdrückung steht deshalb hier an <b>einer</b> Stelle, statt jede
/// Testmethode mit <c>[Obsolete]</c> zu behängen.
/// </summary>
#pragma warning disable CS0618 // Die veralteten Setter sind hier der Testaufbau, siehe oben.
public static class PosteingangAufbau
{
    /// <summary>
    /// Die übliche Gestalt einer Mail mit Anhang: <c>multipart/mixed</c> aus
    /// Textteil „1" und Anhang „2".
    ///
    /// Mit <paramref name="mitHtml"/> die Gestalt, die ein Mailprogramm
    /// erzeugt, das beide Fassungen mitschickt — Textteil und HTML-Teil stecken
    /// dann in einem <c>multipart/alternative</c> („1.1" und „1.2"). Das ist
    /// keine Feinheit: MailKit sucht die Textfassung nur in diesem ersten
    /// Rumpfteil; ein HTML-Teil, der hinter dem Anhang läge, wäre für
    /// <c>HtmlBody</c> unsichtbar — und für den echten Posteingang auch.
    /// </summary>
    public static BodyPartMultipart StrukturMitAnhang(uint textBytes, bool mitHtml = false)
    {
        var body = new BodyPartMultipart { ContentType = new ContentType("multipart", "mixed") };
        body.BodyParts.Add(mitHtml ? Alternative(textBytes) : Text("1", "plain", textBytes));
        body.BodyParts.Add(Anhang("2", "Gutachten.pdf", 50_000));
        return body;
    }

    private static BodyPartMultipart Alternative(uint textBytes)
    {
        var alternative = new BodyPartMultipart
        {
            PartSpecifier = "1",
            ContentType = new ContentType("multipart", "alternative"),
        };
        alternative.BodyParts.Add(Text("1.1", "plain", textBytes));
        alternative.BodyParts.Add(Text("1.2", "html", 400));
        return alternative;
    }

    private static BodyPartText Text(string kennung, string subtyp, uint octets) => new()
    {
        PartSpecifier = kennung,
        ContentType = new ContentType("text", subtyp),
        Octets = octets,
    };

    /// <summary>Ein Anhangsteil mit frei wählbarem Namen und frei wählbarer Größe.</summary>
    public static BodyPartBasic Anhang(string kennung, string dateiname, uint octets) => new()
    {
        PartSpecifier = kennung,
        ContentType = new ContentType("application", "pdf"),
        Octets = octets,
        ContentDisposition = new ContentDisposition("attachment") { FileName = dateiname },
    };

    /// <summary>Der Umschlag, wie ihn eine Antwort der Versicherung mitbringt.</summary>
    public static Envelope Umschlag(
        string betreff = "Ihre Schadenmeldung",
        string absenderName = "HUK-COBURG",
        DateTimeOffset? datum = null)
    {
        var umschlag = new Envelope
        {
            Subject = betreff,
            MessageId = "abc@huk.de",
            Date = datum ?? new DateTimeOffset(2026, 9, 13, 8, 30, 0, TimeSpan.FromHours(2)),
        };
        umschlag.From.Add(new MailboxAddress(absenderName, "schaden@huk.de"));
        umschlag.To.Add(new MailboxAddress("Kanzlei Muster", "kanzlei@example.de"));
        umschlag.Cc.Add(new MailboxAddress(string.Empty, "mandant@example.de"));
        return umschlag;
    }
}
#pragma warning restore CS0618
