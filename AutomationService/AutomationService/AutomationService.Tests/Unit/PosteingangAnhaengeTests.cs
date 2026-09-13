using System.Text;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using MailKit;
using MimeKit;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Was der Anwalt aus dem Posteingang <b>herausholt</b>: einen einzelnen Anhang
/// oder die ganze Nachricht als <c>.eml</c> (§4.3).
///
/// Zwei Eigenschaften entscheiden, ob das taugt. Es muss <em>einzeln und auf
/// Anforderung</em> geschehen — sonst wäre der Posteingang ein Vorrat fremder
/// Dateien auf der Platte des Anwalts. Und es muss <em>begrenzt</em> sein: Der
/// Abruf läuft über dieselbe eine Verbindung wie das Blättern, ein großer Anhang
/// stellte den Posteingang sonst minutenlang still.
/// </summary>
public sealed class PosteingangAnhaengeTests
{
    private static readonly byte[] Inhalt = Encoding.UTF8.GetBytes("Das Gutachten");

    [Fact]
    public async Task Anhang_LandetEntschaerftImZwischenlagerUndWirdNichtZweimalGeholt()
    {
        var (folder, proxy, struktur) = Ordner();
        // Ein Dateiname aus fremder Post ist nichts, was man dem Dateisystem
        // ungeprueft vorlegt: Pfadanteile und Doppelpunkte muessen fallen.
        struktur.BodyParts.Add(PosteingangAufbau.Anhang("3", "..\\Rechnung:2026.pdf", 13));
        proxy.Anhangsteile["3"] = Inhalt;

        var ablage = await PosteingangAnhaenge.LadeAsync(
            folder, "konto", new UniqueId(9001), "3", CancellationToken.None);

        ablage.Dateiname.Should().Be("Rechnung_2026.pdf");
        ablage.Pfad.Should().Contain(Path.Combine("Anhaenge", "Posteingang", "konto", "9001"));
        File.ReadAllBytes(ablage.Pfad).Should().Equal(Inhalt);
        proxy.AnhangAbrufe.Should().Be(1);

        // Derselbe Anhang, derselbe Pfad -- und kein zweiter Abruf: Der Anwalt
        // klickt beim Durchsehen mehrfach auf dieselbe Datei.
        var erneut = await PosteingangAnhaenge.LadeAsync(
            folder, "konto", new UniqueId(9001), "3", CancellationToken.None);
        erneut.Pfad.Should().Be(ablage.Pfad);
        proxy.AnhangAbrufe.Should().Be(1);
    }

    [Fact]
    public async Task Anhang_UeberDerGrenze_WirdGarNichtErstGeholt()
    {
        var (folder, proxy, struktur) = Ordner();
        struktur.BodyParts.Add(PosteingangAufbau.Anhang(
            "3", "Video.pdf", (uint)(PosteingangAnhaenge.MaxAnhangBytes + 1)));
        proxy.Anhangsteile["3"] = Inhalt;

        var holen = () => PosteingangAnhaenge.LadeAsync(
            folder, "konto", new UniqueId(9002), "3", CancellationToken.None);

        (await holen.Should().ThrowAsync<PosteingangException>()).Which.Status.Should().Be(413);
        proxy.AnhangAbrufe.Should().Be(0);
        Directory.EnumerateFiles(PosteingangZwischenlager.Ordner("konto", 9002)).Should().BeEmpty();
    }

    [Theory]
    [InlineData("../../etc/passwd")]
    [InlineData("2;rm")]
    [InlineData("7")]
    public async Task UnbrauchbareOderUnbekannteKennung_Ergibt400(string anhangId)
    {
        var (folder, _, _) = Ordner();

        var holen = () => PosteingangAnhaenge.LadeAsync(
            folder, "konto", new UniqueId(9003), anhangId, CancellationToken.None);

        (await holen.Should().ThrowAsync<PosteingangException>()).Which.Status.Should().Be(400);
    }

    [Fact]
    public async Task VerschwundeneNachricht_Ergibt404()
    {
        var (folder, proxy, _) = Ordner();
        proxy.NachrichtFehlt = true;

        var holen = () => PosteingangAnhaenge.LadeAsync(
            folder, "konto", new UniqueId(9004), "2", CancellationToken.None);

        (await holen.Should().ThrowAsync<PosteingangException>()).Which.Status.Should().Be(404);
    }

    [Fact]
    public async Task Eml_TraegtDatumAbsenderUndBetreff_EntschaerftUndGekuerzt()
    {
        var (folder, proxy, _) = Ordner();
        proxy.Umschlag = PosteingangAufbau.Umschlag(
            betreff: "Schaden 12/34: Rückfrage zu \"Muster\" und dazu noch sehr viel mehr Text, "
                + "damit der Dateiname gekürzt werden muss");
        proxy.Nachricht = Nachricht();

        var ablage = await PosteingangNachrichtAblage.LadeAsync(
            folder, "konto", new UniqueId(9005), CancellationToken.None);

        ablage.Dateiname.Should().StartWith("2026-09-13 HUK-COBURG Schaden 12_34_ Rückfrage zu _Muster_");
        ablage.Dateiname.Should().EndWith(".eml");
        Path.GetFileNameWithoutExtension(ablage.Dateiname).Length
            .Should().BeLessThanOrEqualTo(PosteingangNachrichtAblage.MaxNameZeichen);
        File.Exists(ablage.Pfad).Should().BeTrue();
        ablage.Groesse.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task Eml_UeberDerGrenze_WirdGarNichtErstGeholt()
    {
        var (folder, proxy, _) = Ordner();
        proxy.EinzelGroesse = (uint)(PosteingangNachrichtAblage.MaxEmlBytes + 1);
        proxy.Nachricht = Nachricht();

        var holen = () => PosteingangNachrichtAblage.LadeAsync(
            folder, "konto", new UniqueId(9006), CancellationToken.None);

        (await holen.Should().ThrowAsync<PosteingangException>()).Which.Status.Should().Be(413);
        proxy.NachrichtAbrufe.Should().Be(0);
        Directory.EnumerateFiles(PosteingangZwischenlager.Ordner("konto", 9006)).Should().BeEmpty();
    }

    private static (IMailFolder Folder, PosteingangOrdnerProxy Proxy, BodyPartMultipart Struktur) Ordner()
    {
        var (folder, proxy) = PosteingangOrdnerProxy.Erzeuge();
        var struktur = PosteingangAufbau.StrukturMitAnhang(100);
        proxy.InhaltStruktur = struktur;
        proxy.Umschlag = PosteingangAufbau.Umschlag();
        return (folder, proxy, struktur);
    }

    private static MimeMessage Nachricht()
    {
        var nachricht = new MimeMessage { Subject = "Ihre Schadenmeldung" };
        nachricht.From.Add(new MailboxAddress("HUK-COBURG", "schaden@huk.de"));
        nachricht.To.Add(new MailboxAddress("Kanzlei Muster", "kanzlei@example.de"));
        nachricht.Body = new TextPart("plain") { Text = "Guten Tag," };
        return nachricht;
    }
}
