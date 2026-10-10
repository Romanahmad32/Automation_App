using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using MailKit;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

public sealed class PosteingangTests
{
    [Fact]
    public async Task Monitor_LaedtBeiNormalenMailsNurDieJuenstenKoepfe()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        var scanner = new MailboxNachrichtenScanner(new MailboxOptions(), null!, null!,
            NullLogger.Instance, (_, _) => Task.CompletedTask);
        await scanner.ScanRecentAsync(folder, CancellationToken.None);
        proxy.Abrufe.Should().ContainSingle();
        (proxy.Abrufe[0].Ende - proxy.Abrufe[0].Start + 1).Should().Be(20);
    }

    [Theory]
    [InlineData(100u, 1, false)]
    [InlineData(400000u, 0, true)]
    public async Task Oeffnen_LaedtNurTextteil_KeinenGrossenAnhang(uint textBytes, int textAbrufe, bool begrenzt)
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.InhaltStruktur = PosteingangAufbau.StrukturMitAnhang(textBytes);
        var inhalt = await PosteingangText.LadeAsync(folder, new UniqueId(1), CancellationToken.None);
        proxy.TextAbrufe.Should().Be(textAbrufe);
        proxy.AnhangAbrufe.Should().Be(0);
        inhalt.Gekuerzt.Should().Be(begrenzt);
        inhalt.Anhaenge.Should().ContainSingle().Which.Dateiname.Should().Be("Gutachten.pdf");
        if (!begrenzt)
        {
            inhalt.Text.Should().Be("Der Mailtext");
        }
    }

    [Fact]
    public async Task Oeffnen_LiefertNebenDemTextEinEntschaerftesHtml()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.InhaltStruktur = PosteingangAufbau.StrukturMitAnhang(100, mitHtml: true);
        proxy.Umschlag = PosteingangAufbau.Umschlag();
        proxy.Textteile["1.1"] = "Der Mailtext";
        proxy.Textteile["1.2"] = "<p>Guten Tag<script>alert(1)</script>"
            + "<img src=\"https://werbe.example/zaehlpixel.gif\"></p>";
        proxy.HtmlTeile.Add("1.2");

        var inhalt = await PosteingangText.LadeAsync(folder, new UniqueId(1), CancellationToken.None);

        // Hoechstens zwei Teile je Oeffnen: die Textfassung und die HTML-Fassung.
        proxy.TextAbrufe.Should().Be(2);
        proxy.AnhangAbrufe.Should().Be(0);
        inhalt.Text.Should().Be("Der Mailtext");
        inhalt.Html.Should().NotBeNull();
        inhalt.Html.Should().NotContain("script").And.NotContain("https://werbe.example");
        inhalt.Html.Should().Contain("data-blockiert=\"1\"");
        inhalt.BilderBlockiert.Should().BeTrue();
        inhalt.AbsenderName.Should().Be("HUK-COBURG");
        inhalt.AbsenderAdresse.Should().Be("schaden@huk.de");
        inhalt.An.Should().Equal("Kanzlei Muster <kanzlei@example.de>");
        inhalt.Cc.Should().Equal("mandant@example.de");
        inhalt.MessageId.Should().Be("abc@huk.de");
        var anhang = inhalt.Anhaenge.Should().ContainSingle().Subject;
        anhang.Id.Should().Be("2");
        anhang.Medientyp.Should().Be("application/pdf");
    }

    [Fact]
    public async Task OhneNachladendeQuelle_BleibtBilderBlockiertFalse()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.InhaltStruktur = PosteingangAufbau.StrukturMitAnhang(100, mitHtml: true);
        proxy.Umschlag = PosteingangAufbau.Umschlag();
        proxy.Textteile["1.1"] = "Der Mailtext";
        proxy.Textteile["1.2"] = "<p>Guten Tag, anbei die Schadennummer HUK-4711.</p>";
        proxy.HtmlTeile.Add("1.2");

        var inhalt = await PosteingangText.LadeAsync(folder, new UniqueId(1), CancellationToken.None);

        inhalt.Html.Should().NotContain("data-blockiert");
        inhalt.BilderBlockiert.Should().BeFalse();
    }

    [Fact]
    public async Task MillionMails_LaedtNurFuenfzigKoepfe_OhneTextOderAnhaenge()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        var seite = await PosteingangLeser.LadeAsync(folder, "konto", null, CancellationToken.None);
        seite.Nachrichten.Should().HaveCount(50);
        seite.Nachrichten[0].Betreff.Should().Be("Kanzleimail 1000000");
        proxy.Abrufe.Should().ContainSingle();
        proxy.Abrufe[0].Start.Should().Be(999950);
        proxy.Abrufe[0].Ende.Should().Be(999999);
        // BODYSTRUCTURE ist seit Issue #134 ausdruecklich erlaubt: Sie
        // beschreibt nur, aus welchen Teilen eine Nachricht besteht -- daher
        // die Bueroklammer und die Anhangszahl in der Liste --, und laedt
        // dabei keinen Inhalt. Body und PreviewText bleiben verboten: Das
        // sind die beiden Felder, die Mailtext ueber die Leitung holen
        // wuerden, und genau das soll die Liste auch bei einer Million Mails
        // nicht tun.
        (proxy.Abrufe[0].Felder & (MessageSummaryItems.Body | MessageSummaryItems.PreviewText))
            .Should().Be(MessageSummaryItems.None);
        proxy.Abrufe[0].Felder.Should().HaveFlag(MessageSummaryItems.BodyStructure);
        proxy.TextAbrufe.Should().Be(0);
        proxy.AnhangAbrufe.Should().Be(0);
    }

    [Fact]
    public async Task Liste_ZaehltAnhaengeAusDerStruktur_UndZerlegtDenUmschlag()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.Anzahl = 1;
        proxy.InhaltStruktur = PosteingangAufbau.StrukturMitAnhang(100);
        proxy.Umschlag = PosteingangAufbau.Umschlag();

        var seite = await PosteingangLeser.LadeAsync(folder, "konto", null, CancellationToken.None);

        var eintrag = seite.Nachrichten.Should().ContainSingle().Subject;
        eintrag.HatAnhaenge.Should().BeTrue();
        eintrag.AnzahlAnhaenge.Should().Be(1);
        eintrag.AbsenderName.Should().Be("HUK-COBURG");
        eintrag.AbsenderAdresse.Should().Be("schaden@huk.de");
        eintrag.An.Should().Equal("Kanzlei Muster <kanzlei@example.de>");
        eintrag.Cc.Should().Equal("mandant@example.de");
        // Ohne spitze Klammern -- so steht der Dedupe-Schluessel auch an der
        // erfassten Zentralruf-Antwort, und nur so lassen sich beide Seiten
        // ueberhaupt vergleichen.
        eintrag.MessageId.Should().Be("abc@huk.de");
        proxy.TextAbrufe.Should().Be(0);
        proxy.AnhangAbrufe.Should().Be(0);
    }

    [Fact]
    public async Task ZweiteSeite_BleibtBeiNeueingangUndGeloeschtenMailsLueckenlos()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.Anzahl = 120;
        var erste = await PosteingangLeser.LadeAsync(folder, "konto", null, CancellationToken.None);
        // UID 1 bis 10 wurden inzwischen gelöscht; UID 121 bis 125 kamen hinzu.
        proxy.Anzahl = 115;
        proxy.UidAmIndex = index => (uint)(index + 11);
        proxy.Abrufe.Clear();
        var zweite = await PosteingangLeser.LadeAsync(folder, "konto", erste.NaechsteSeite, CancellationToken.None);
        zweite.Nachrichten.Select(mail => mail.Betreff).Should().Equal(
            Enumerable.Range(21, 50).Reverse().Select(uid => $"Kanzleimail {uid}"));
        proxy.Abrufe.Sum(abruf => abruf.Ende - abruf.Start + 1).Should().BeLessThanOrEqualTo(57);
        var dritte = await PosteingangLeser.LadeAsync(folder, "konto", zweite.NaechsteSeite, CancellationToken.None);
        dritte.Nachrichten.Should().HaveCount(10);
        dritte.NaechsteSeite.Should().BeNull();
    }

    [Fact]
    public async Task LeererOrdner_FuehrtKeinenFetchAus()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.Anzahl = 0;
        var seite = await PosteingangLeser.LadeAsync(folder, "konto", null, CancellationToken.None);
        seite.Nachrichten.Should().BeEmpty();
        seite.NaechsteSeite.Should().BeNull();
        proxy.Abrufe.Should().BeEmpty();
    }

    [Theory]
    [InlineData("anderes-konto", 17u)]
    [InlineData("konto", 18u)]
    public void AlteKennung_DarfKeineAndereNachrichtOeffnen(string konto, uint gueltigkeit)
    {
        var id = new PosteingangKennung("konto", 17, 25).Encode();
        var lesen = () => PosteingangKennung.Decode(id, konto, gueltigkeit);
        lesen.Should().Throw<PosteingangException>().Which.Status.Should().Be(409);
    }

    [Fact]
    public async Task OhneMessageId_ListenEintragTraegtDenSchluesselDesScanners()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.Anzahl = 1;
        var umschlag = PosteingangAufbau.Umschlag();
        umschlag.MessageId = null;
        proxy.Umschlag = umschlag;

        var seite = await PosteingangLeser.LadeAsync(folder, "konto", null, CancellationToken.None);

        // "17" ist die von PosteingangOrdnerProxy vorgegebene UidValidity, "1"
        // die einzige UID (proxy.Anzahl = 1); PosteingangKopf.MailSchluessel
        // ist derselbe Rueckfall, den auch MailboxNachrichtenScanner fuer den
        // Dedupe-Schluessel bildet -- nur ueber dieselbe Methode bleiben beide
        // Seiten deckungsgleich.
        var erwarteterSchluessel = PosteingangKopf.MailSchluessel(null, 17u, 1u);
        erwarteterSchluessel.Should().Be("17:1");
        seite.Nachrichten.Should().ContainSingle().Which.MessageId.Should().Be(erwarteterSchluessel);
    }

    [Fact]
    public async Task OhneMessageId_GeoeffneterInhaltTraegtDenselbenSchluessel()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        proxy.InhaltStruktur = PosteingangAufbau.StrukturMitAnhang(100);
        var umschlag = PosteingangAufbau.Umschlag();
        umschlag.MessageId = null;
        proxy.Umschlag = umschlag;

        var inhalt = await PosteingangText.LadeAsync(folder, new UniqueId(1), CancellationToken.None);

        inhalt.MessageId.Should().Be(PosteingangKopf.MailSchluessel(null, 17u, 1u));
    }

    [Fact]
    public async Task UidLuecken_BinaereSucheBleibtBegrenzt()
    {
        var abrufe = 0;
        var index = await PosteingangLeser.FindeGrenzeAsync(1_000_000, 1_234_567, i =>
        {
            abrufe++;
            return Task.FromResult((uint)((i * 3) + 1));
        });
        index.Should().Be(411522);
        abrufe.Should().BeLessThanOrEqualTo(20);
    }
}
