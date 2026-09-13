using AutomationService.Features.MailboxMonitor.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Post von Unbekannten wird in der Kanzlei angezeigt — also darf sie zwei
/// Dinge nicht können: etwas ausführen und etwas nachladen.
///
/// Das Zweite ist das weniger offensichtliche und das im Alltag wichtigere: Ein
/// externes Bild meldet dem Absender Zeitpunkt und IP-Adresse des Lesens. In
/// einer Anwaltskanzlei ist das eine Auskunft über Mandatsarbeit, die niemand
/// erteilt hat.
/// </summary>
public sealed class PosteingangHtmlFilterTests
{
    [Theory]
    [InlineData("<p>Hallo<script>alert(1)</script></p>", "script")]
    [InlineData("<style>body{color:red}</style><p>Hallo</p>", "style")]
    [InlineData("<p onclick=\"stehlen()\">Hallo</p>", "onclick")]
    [InlineData("<iframe src=\"https://x.example\"></iframe><p>Hallo</p>", "iframe")]
    [InlineData("<link rel=\"stylesheet\" href=\"https://x.example/a.css\"><p>Hallo</p>", "link")]
    [InlineData("<link rel=\"preload\" as=\"image\" href=\"https://x.example/a.png\"><p>Hallo</p>", "preload")]
    [InlineData("<meta http-equiv=\"refresh\" content=\"0;url=https://x.example\">", "http-equiv")]
    [InlineData("<a href=\"javascript:stehlen()\">Hier</a>", "javascript:")]
    [InlineData("<base href=\"https://fremd.example/\"><img src=\"bild.png\">", "base")]
    [InlineData("<object data=\"https://werbe.example/spur.swf\"></object><p>Hallo</p>", "object")]
    [InlineData("<style>@import url('https://werbe.example/spur.css');</style><p>Hallo</p>", "werbe.example")]
    public void AktivesUndNachladendesVerschwindet(string html, string darfNichtBleiben)
    {
        var gefiltert = PosteingangHtmlFilter.FuerAnzeige(html);

        gefiltert.Should().NotContain(darfNichtBleiben);
    }

    [Fact]
    public void BasisAdresse_MachtRelativenVerweisNichtUnschaedlich()
    {
        // <base> biegt jeden relativen Verweis auf eine fremde Adresse um --
        // ohne <base> ist "bild.png" harmlos. Das Element selbst muss also
        // weg, das (weiterhin relative) Bild darf stehen bleiben.
        var gefiltert = PosteingangHtmlFilter.FuerAnzeige(
            "<base href=\"https://fremd.example/\"><img src=\"bild.png\">");

        gefiltert.Should().NotContain("<base").And.NotContain("fremd.example");
        gefiltert.Should().Contain("bild.png");
    }

    [Theory]
    [InlineData("<img src=\"https://werbe.example/pixel.gif\">")]
    [InlineData("<img src='http://werbe.example/pixel.gif'>")]
    [InlineData("<img src=//werbe.example/pixel.gif>")]
    [InlineData("<td background=\"https://werbe.example/hintergrund.png\">Zelle</td>")]
    [InlineData("<img src=\"cid:eingebettet\">")]
    [InlineData("<img srcset=\"https://werbe.example/a.png 1x, https://werbe.example/b.png 2x\">")]
    [InlineData("<video poster=\"https://werbe.example/vorschau.jpg\"></video>")]
    public void NachladendeBilder_BleibenLeerUndMarkiert(string html)
    {
        var gefiltert = PosteingangHtmlFilter.FuerAnzeige(html);

        gefiltert.Should().NotContain("werbe.example").And.NotContain("cid:");
        // Die Marke bleibt stehen und traegt den Hinweis: Die Oberflaeche sagt
        // dem Anwalt dann, dass Bilder zurueckgehalten wurden -- statt ihn vor
        // einer lueckenhaften Nachricht ohne Erklaerung sitzen zu lassen.
        gefiltert.Should().Contain("data-blockiert=\"1\"");
    }

    [Fact]
    public void HintergrundbilderImStil_FallenEbenfalls()
    {
        var gefiltert = PosteingangHtmlFilter.FuerAnzeige(
            "<div style=\"background:url('https://werbe.example/pixel.gif')\">Text</div>");

        gefiltert.Should().NotContain("werbe.example");
        gefiltert.Should().Contain("Text");
    }

    [Theory]
    [InlineData("<img src=\"https://werbe.example/pixel.gif\"><p>Hallo</p>", true)]
    [InlineData("<base href=\"https://fremd.example/\"><p>Hallo</p>", true)]
    [InlineData("<p><b>Sehr geehrte Damen und Herren,</b> anbei die Akte.</p>", false)]
    public void FuerAnzeigeMitErgebnis_MeldetBilderBlockiert(string html, bool erwartet)
    {
        var ergebnis = PosteingangHtmlFilter.FuerAnzeigeMitErgebnis(html);

        ergebnis.BilderBlockiert.Should().Be(erwartet);
        ergebnis.Html.Should().Be(PosteingangHtmlFilter.FuerAnzeige(html));
    }

    [Fact]
    public void DerLesbareTeil_BleibtUnangetastet()
    {
        const string html = "<p><b>Sehr geehrte Damen und Herren,</b><br>"
            + "anbei die Schadennummer <a href=\"https://huk.de/akte\">HUK-4711</a>.</p>";

        var gefiltert = PosteingangHtmlFilter.FuerAnzeige(html);

        // Ein gewoehnlicher Verweis bleibt: Er laedt nichts nach, solange
        // niemand darauf klickt.
        gefiltert.Should().Be(html);
    }

    [Fact]
    public void LeeresHtml_BleibtLeer()
    {
        PosteingangHtmlFilter.FuerAnzeige(string.Empty).Should().BeEmpty();
    }
}
