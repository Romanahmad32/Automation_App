using System.Text;
using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Übernahme der Signatur aus Outlook (§4.7): den Rumpf schneiden, die
/// Bilder einsammeln, ihre Verweise kürzen — und je Mail einzelne davon wieder
/// herausnehmen.
///
/// Der teuerste Fehler ist hier still: eine Signatur, die beim Empfänger ein
/// Platzhalterkreuz zeigt, weil ein Bild zwar erwähnt, aber nicht mitgeschickt
/// wurde. Deshalb prüfen die Tests nicht nur, was mitkommt, sondern auch, dass
/// von allem anderen <b>kein Verweis</b> stehen bleibt.
/// </summary>
public sealed class SignaturUebernahmeTests : IDisposable
{
    private readonly string _ordner =
        Path.Combine(Path.GetTempPath(), $"SignaturUebernahme_{Guid.NewGuid():N}");

    public SignaturUebernahmeTests() => Directory.CreateDirectory(_ordner);

    private string Datei(string name, byte[] inhalt) =>
        SignaturProben.Datei(_ordner, name, inhalt);

    private static byte[] Bild(int bytes) => SignaturProben.Bild(bytes);

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
        gelesen!.Html.Should().NotContain("<style>").And.Contain("Gr&uuml;&szlig;en");
        // Der Verweis ist auf den blanken Dateinamen gekuerzt -- der Beiordner
        // des Absenders existiert beim Empfaenger nicht.
        gelesen.Html.Should().Contain("src=\"logo.png\"");
        gelesen.Bilder.Should().ContainKey("logo.png");
    }

    [Fact]
    public void OutlookSignaturHtml_LaesstVerweiseInsNetzStehen()
    {
        var htm = Datei("Web.htm", Encoding.UTF8.GetBytes(
            "<body><img src=\"https://kanzlei.example.de/logo.png\"></body>"));

        var gelesen = OutlookSignaturHtml.Lies(htm);

        gelesen!.Html.Should().Contain("https://kanzlei.example.de/logo.png");
        gelesen.Bilder.Should().BeEmpty();
    }

    [Fact]
    public void OutlookSignaturHtml_NimmtEinGifWieJedesAndereBild()
    {
        // Kein Formatfilter im Uebernahmeweg: Was Outlook in seinem Beiordner
        // fuehrt, geht mit -- sonst fehlte ausgerechnet das Bild, um das es
        // beim Abwaehlen geht.
        Datei("Kanzlei-Dateien/werbung.gif", SignaturProben.AnimiertesGif());
        var htm = Datei("MitGif.htm", Encoding.UTF8.GetBytes(
            "<body><img src=\"Kanzlei-Dateien/werbung.gif\"></body>"));

        var gelesen = OutlookSignaturHtml.Lies(htm);

        gelesen!.Bilder.Should().ContainKey("werbung.gif");
        gelesen.Bilder["werbung.gif"].Should().Equal(SignaturProben.AnimiertesGif());
        gelesen.Html.Should().Contain("src=\"werbung.gif\"");
    }

    /// <summary>
    /// Ein Bild, das nicht mitgenommen werden kann, darf auch nicht mehr
    /// erwaehnt werden.
    ///
    /// Vorher blieb sein relativer Verweis stehen — beim Empfaenger ein Pfad,
    /// der auf nichts zeigt, also ein Platzhalterkreuz mitten in der
    /// Kanzleisignatur. Und niemand hatte es gesagt: nicht beim Uebernehmen,
    /// nicht beim Senden.
    /// </summary>
    [Fact]
    public void OutlookSignaturHtml_EntferntDieMarkeEinesZuGrossenBildes()
    {
        Datei("Kanzlei-Dateien/logo.png", Bild(120));
        Datei("Kanzlei-Dateien/riesig.gif", Bild((int)SignaturAblage.MaxBildBytes + 1));
        var htm = Datei("ZuGross.htm", Encoding.UTF8.GetBytes(
            "<body><img src=\"Kanzlei-Dateien/logo.png\">"
            + "<img src=\"Kanzlei-Dateien/riesig.gif\" alt=\"Werbung\"></body>"));

        var gelesen = OutlookSignaturHtml.Lies(htm);

        gelesen.Should().NotBeNull();
        // Weder der Verweis noch die Marke drumherum bleiben stehen.
        gelesen!.Html.Should().NotContain("riesig.gif").And.NotContain("alt=\"Werbung\"");
        gelesen.Bilder.Should().NotContainKey("riesig.gif");
        // Und der Anwalt erfaehrt, welches Bild fehlt.
        gelesen.Uebergangen.Should().ContainSingle().Which.Should().Contain("riesig.gif");
        // Das brauchbare Bild bleibt unberuehrt.
        gelesen.Html.Should().Contain("src=\"logo.png\"");
    }

    [Fact]
    public void OutlookSignaturHtml_EinFehlendesBildGiltEbenfalls()
    {
        var htm = Datei("Fehlt.htm", Encoding.UTF8.GetBytes(
            "<body><img src=\"Kanzlei-Dateien/weg.png\"></body>"));

        var gelesen = OutlookSignaturHtml.Lies(htm);

        gelesen!.Html.Should().NotContain("weg.png");
        gelesen.Uebergangen.Should().ContainSingle();
    }

    [Fact]
    public void OutlookSignaturHtml_EinVerweisInsNetzGiltNichtAlsUebergangen()
    {
        // Er zeigt auf einen Server, der ihn ausliefert — dass wir ihn nicht
        // einsammeln, ist Absicht und kein Verlust.
        var htm = Datei("Web2.htm", Encoding.UTF8.GetBytes(
            "<body><img src=\"https://kanzlei.example.de/logo.png\"></body>"));

        var gelesen = OutlookSignaturHtml.Lies(htm);

        gelesen!.Html.Should().Contain("https://kanzlei.example.de/logo.png");
        gelesen.Uebergangen.Should().BeEmpty();
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

    /// <summary>
    /// Der Fall aus der Kanzlei: Word schreibt jedes Signaturbild zweimal — als
    /// VML-Form für Outlook und als <c>img</c> für alle übrigen Programme. Wer
    /// nur das <c>img</c> entfernt, hat das Bild abgewählt und schickt es
    /// trotzdem: Outlook zeichnet die Form, und der Dateiname steht noch im
    /// HTML, also wird die Datei weiter mitgeschickt.
    /// </summary>
    [Fact]
    public void SignaturHtmlFilter_NimmtAuchDieVmlFassungHeraus()
    {
        const string html =
            "<p>Gruss</p><!--[if gte vml 1]><v:shapetype id=\"_x0000_t75\"></v:shapetype>"
            + "<v:shape id=\"_x0000_i1025\" type=\"#_x0000_t75\" style='width:246pt'>"
            + "<v:imagedata src=\"werbung.gif\" o:title=\"\"/></v:shape><![endif]-->"
            + "<![if !vml]><img width=328 height=143\r\nsrc=\"werbung.gif\"><![endif]>"
            + "<v:shape><v:imagedata src=\"logo.png\"/></v:shape>";

        var uebrig = SignaturHtmlFilter.Ohne(html, new HashSet<string> { "werbung.gif" });

        uebrig.Should().NotContain("werbung.gif");
        uebrig.Should().NotContain("_x0000_i1025");
        // Was bleiben soll, bleibt in beiden Fassungen stehen.
        uebrig.Should().Contain("logo.png");
        SignaturHtmlFilter.Verwendete(uebrig, [new SignaturBild("werbung.gif", 4_000_000)])
            .Should().BeEmpty();
    }

    /// <summary>
    /// Ein Hintergrundbild haengt an einer Tabellenzelle, nicht an einer
    /// eigenen Marke. Bliebe der Verweis stehen, waere das Bild abgewaehlt und
    /// ginge trotzdem mit hinaus: Verwendete faende den Dateinamen wieder, und
    /// MailRumpf bettete die Datei ein.
    /// </summary>
    [Fact]
    public void SignaturHtmlFilter_NimmtAuchDasHintergrundbildHeraus()
    {
        const string html =
            "<table><tr><td background=\"werbung.gif\" valign=\"top\">Kanzlei</td>"
            + "<td background=\"logo.png\">RA</td></tr></table>";

        var uebrig = SignaturHtmlFilter.Ohne(html, new HashSet<string> { "werbung.gif" });

        uebrig.Should().NotContain("werbung.gif");
        // Die Zelle bleibt mit allem, was in ihr steht: Sie herauszunehmen
        // hiesse, die Signatur auseinanderzunehmen.
        uebrig.Should().Contain("Kanzlei").And.Contain("valign=\"top\"");
        uebrig.Should().Contain("background=\"logo.png\"");
        SignaturHtmlFilter.Verwendete(uebrig, [new SignaturBild("werbung.gif", 4_000_000)])
            .Should().BeEmpty();
    }

    [Fact]
    public void SignaturHtmlFilter_ZaehltDasHintergrundbildAlsOertlicheQuelle()
    {
        // Sonst faende das Netz gegen tote Verweise (KanzleiSignatur) es nicht,
        // und eine geloeschte Datei bliebe als background= in der Mail stehen.
        const string html = "<td background=\"logo.png\">RA</td>";

        SignaturHtmlFilter.OertlicheQuellen(html).Should().Equal("logo.png");
    }

    [Fact]
    public void SignaturHtmlFilter_MeldetNurDieNochVerwendetenBilder()
    {
        const string html = "<img src=\"logo.png\">";
        SignaturBild[] abgelegt = [new("logo.png", 100), new("werbung.gif", 4_000_000)];

        SignaturHtmlFilter.Verwendete(html, abgelegt).Should().Equal("logo.png");
    }

    [Fact]
    public void SignaturHtmlFilter_MeldetNurDieOertlichenQuellen()
    {
        const string html =
            "<img src=\"logo.png\"><img src=\"https://example.de/a.png\">"
            + "<img src=\"cid:abc\"><img src=\"data:image/png;base64,AA\">";

        SignaturHtmlFilter.OertlicheQuellen(html).Should().Equal("logo.png");
    }

    [Fact]
    public void SignaturAblage_LiefertGifsAlsBildAus()
    {
        // Die Vorschau laedt das Bild ueber den Dienst; mit
        // application/octet-stream zeigte sie es nicht an.
        SignaturAblage.InhaltsArt("werbung.gif").Should().Be("image/gif");
    }

    public void Dispose()
    {
        if (Directory.Exists(_ordner))
        {
            Directory.Delete(_ordner, recursive: true);
        }
    }
}
