using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using MailKit;
using Microsoft.Extensions.Logging.Abstractions;
using MimeKit;
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
    [Obsolete("Baut die BodyPart-Struktur von Hand; MimeKit hat deren Setter als veraltet markiert — genau das ist hier der Testaufbau.")]
    public async Task Oeffnen_LaedtNurTextteil_KeinenGrossenAnhang(uint textBytes, int textAbrufe, bool begrenzt)
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        var body = new BodyPartMultipart { ContentType = new ContentType("multipart", "mixed") };
        body.BodyParts.Add(new BodyPartText
        {
            PartSpecifier = "1",
            ContentType = new ContentType("text", "plain"),
            Octets = textBytes,
        });
        body.BodyParts.Add(new BodyPartBasic
        {
            PartSpecifier = "2",
            ContentType = new ContentType("application", "pdf"),
            Octets = 50_000_000,
            ContentDisposition = new ContentDisposition("attachment") { FileName = "Gutachten.pdf" },
        });
        proxy.InhaltStruktur = body;
        var inhalt = await PosteingangText.LadeAsync(folder, new UniqueId(1), CancellationToken.None);
        proxy.TextAbrufe.Should().Be(textAbrufe);
        inhalt.Gekuerzt.Should().Be(begrenzt);
        inhalt.Anhaenge.Should().ContainSingle().Which.Should().Be("Gutachten.pdf");
        if (!begrenzt)
        {
            inhalt.Text.Should().Be("Der Mailtext");
        }
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
        (proxy.Abrufe[0].Felder & (MessageSummaryItems.Body | MessageSummaryItems.BodyStructure | MessageSummaryItems.PreviewText))
            .Should().Be(MessageSummaryItems.None);
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
