using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Versandweg (§4.7): Aus dem Postfach-Zugang, den der Anwalt einmal für
/// den Empfang eingerichtet hat, muss der Postausgang ohne weiteres Zutun
/// folgen — und ein fehlender oder unlesbarer Anhang muss den Versand
/// verhindern, bevor irgendetwas hinausgeht.
/// </summary>
public sealed class EmailVersandTests : IDisposable
{
    private readonly string _ordner =
        Path.Combine(Path.GetTempPath(), $"EmailVersandTests_{Guid.NewGuid():N}");

    private static MailboxOptions Postfach(string host, string benutzer = "kanzlei@example.de") => new()
    {
        Host = host,
        Username = benutzer,
        AppPassword = "app-passwort",
    };

    [Theory]
    [InlineData("imap.ionos.de", "smtp.ionos.de")]
    [InlineData("imap.gmail.com", "smtp.gmail.com")]
    [InlineData("outlook.office365.com", "smtp.office365.com")]
    [InlineData("imap.strato.de", "smtp.strato.de")]
    public void SmtpZugang_LeitetDenPostausgangAusDemPosteingangAb(string imap, string erwartet)
    {
        var zugang = SmtpZugang.Aus(Postfach(imap), new EmailVersandOptions());

        zugang.Should().NotBeNull();
        zugang!.Host.Should().Be(erwartet);
        zugang.Port.Should().Be(587);
        zugang.Absender.Should().Be("kanzlei@example.de");
    }

    [Fact]
    public void SmtpZugang_AppsettingsSchlagenDieAbleitung()
    {
        // Private Outlook.com-Konten senden nicht über smtp.office365.com —
        // dafür ist der Überschreibweg da.
        var zugang = SmtpZugang.Aus(
            Postfach("outlook.office365.com"),
            new EmailVersandOptions { SmtpHost = "smtp-mail.outlook.com", SmtpPort = 25 });

        zugang!.Host.Should().Be("smtp-mail.outlook.com");
        zugang.Port.Should().Be(25);
    }

    [Fact]
    public void SmtpZugang_GmailLegtDieKopieSelbstAb()
    {
        // Sonst läge dieselbe Mail zweimal im Ordner "Gesendet".
        SmtpZugang.Aus(Postfach("imap.gmail.com"), new EmailVersandOptions())!
            .ServerLegtKopieSelbstAb.Should().BeTrue();
        SmtpZugang.Aus(Postfach("outlook.office365.com"), new EmailVersandOptions())!
            .ServerLegtKopieSelbstAb.Should().BeFalse();
    }

    [Fact]
    public void SmtpZugang_OhneHinterlegtenZugang_IstNull()
    {
        SmtpZugang.Aus(new MailboxOptions(), new EmailVersandOptions()).Should().BeNull();
    }

    [Fact]
    public void AnhangPruefung_FehlendeDatei_NenntSieBeimNamen()
    {
        var fehlend = Path.Combine(_ordner, "Anspruchsschreiben.pdf");

        var aufruf = () => AnhangPruefung.Lade([fehlend], 20);

        aufruf.Should().Throw<EmailVersandException>()
            .Where(fehler => fehler.Grund == EmailVersandFehler.Anhang)
            .WithMessage("*Anspruchsschreiben.pdf*");
    }

    [Fact]
    public void AnhangPruefung_ZuGrossesPaket_WirdVorDemVersandAbgelehnt()
    {
        Directory.CreateDirectory(_ordner);
        var datei = Path.Combine(_ordner, "Gutachten.pdf");
        File.WriteAllBytes(datei, new byte[2 * 1024 * 1024]);

        var aufruf = () => AnhangPruefung.Lade([datei], 1);

        aufruf.Should().Throw<EmailVersandException>()
            .Where(fehler => fehler.Grund == EmailVersandFehler.Anhang)
            .WithMessage("*1 MB*");
    }

    [Fact]
    public void AnhangPruefung_LiestAuchEineInWordGeoeffneteDatei()
    {
        // Word hält die .docx offen, während der Anwalt sie noch korrigiert.
        // Ein Anhang, der nur deshalb scheitert, wäre eine Schikane.
        Directory.CreateDirectory(_ordner);
        var datei = Path.Combine(_ordner, "Schreiben.docx");
        File.WriteAllText(datei, "Inhalt");

        using var offen = new FileStream(datei, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var geladen = AnhangPruefung.Lade([datei], 20);

        geladen.Should().ContainSingle();
        geladen[0].Dateiname.Should().Be("Schreiben.docx");
    }

    [Fact]
    public void NachrichtBauer_UngueltigeAdresse_NenntDieEingabe()
    {
        var zugang = SmtpZugang.Aus(Postfach("imap.gmail.com"), new EmailVersandOptions())!;
        var nachricht = new EmailNachricht(
            ["kein-at-zeichen"],
            [],
            "Anspruchsschreiben",
            "Sehr geehrte Damen und Herren,",
            [],
            "Kanzlei");

        var aufruf = () => EmailNachrichtBauer.Baue(nachricht, zugang.Absender, []);

        aufruf.Should().Throw<EmailVersandException>()
            .Where(fehler => fehler.Grund == EmailVersandFehler.Adresse)
            .WithMessage("*kein-at-zeichen*");
    }

    [Fact]
    public void NachrichtBauer_SetztAbsenderEmpfaengerUndAnhang()
    {
        var zugang = SmtpZugang.Aus(Postfach("imap.gmail.com"), new EmailVersandOptions())!;
        var nachricht = new EmailNachricht(
            ["versicherung@example.de"],
            ["mandant@example.de", "   "],
            "Anspruchsschreiben 84/26 C03",
            "Sehr geehrte Damen und Herren,",
            [],
            "Kanzlei Muster");

        var mime = EmailNachrichtBauer.Baue(
            nachricht,
            zugang.Absender,
            [new GeladenerAnhang("Anspruchsschreiben.pdf", [1, 2, 3])]);

        mime.From.Mailboxes.Single().Address.Should().Be("kanzlei@example.de");
        mime.To.Mailboxes.Single().Address.Should().Be("versicherung@example.de");
        mime.Cc.Mailboxes.Should().ContainSingle(adresse => adresse.Address == "mandant@example.de");
        mime.Attachments.Should().ContainSingle();
    }

    [Fact]
    public void NachrichtBauer_OhneEmpfaenger_SendetNicht()
    {
        var zugang = SmtpZugang.Aus(Postfach("imap.gmail.com"), new EmailVersandOptions())!;
        var nachricht = new EmailNachricht([], [], "Betreff", "Text", [], "Kanzlei");

        var aufruf = () => EmailNachrichtBauer.Baue(nachricht, zugang.Absender, []);

        aufruf.Should().Throw<EmailVersandException>()
            .Where(fehler => fehler.Grund == EmailVersandFehler.Adresse);
    }

    public void Dispose()
    {
        if (Directory.Exists(_ordner))
        {
            Directory.Delete(_ordner, recursive: true);
        }
    }
}
