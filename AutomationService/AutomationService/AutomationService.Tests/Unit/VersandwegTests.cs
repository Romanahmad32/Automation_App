using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MimeKit;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Versandweg von vorn bis hinten (§4.7) -- mit falschem Transport, echter
/// Datenbank und den echten Diensten dazwischen.
///
/// Die vorhandenen Tests decken die Teile ab: Signatur, Anhangpruefung,
/// Protokoll. Was keiner von ihnen beantwortet, sind die Fragen an den
/// <b>Zusammenhang</b> -- und genau die sind die teuren:
///
/// <list type="bullet">
/// <item>Wird protokolliert, wenn die Kopie in "Gesendet" misslingt?</item>
/// <item>Wird <b>nicht</b> protokolliert, wenn die Einlieferung scheitert?</item>
/// <item>Steht im Protokoll der Anhangname, unter dem die Datei
///   <i>hinausging</i>, und nicht der auf der Platte?</item>
/// </list>
///
/// Sie liessen sich bisher nur erlesen. Moeglich wird das durch die beiden
/// Nahten <see cref="ISmtpUebergabe"/> und <see cref="IGesendetOrdnerAblage"/>:
/// alles davor und danach laeuft echt, nur das Hinausgehen ist gefaelscht.
/// </summary>
public sealed class VersandwegTests : IDisposable
{
    private readonly SqliteConnection _verbindung;
    private readonly AutomationDbContext _db;
    private readonly FalscherTransport _transport = new();
    private readonly FalscheGesendetAblage _gesendet = new();
    private readonly string _anhangPfad;

    // Jeder Versender bringt einen MicrosoftMailOAuthService mit, und der haelt
    // eine SemaphoreSlim. Ungenutzt bleibt sie hier zwar immer -- gefragt wird
    // der Dienst nur bei einem Microsoft-Postfach --, gebaut wird er trotzdem
    // je Aufruf. Wer sie nicht einsammelt, laesst je Testmethode eine liegen.
    private readonly List<MicrosoftMailOAuthService> _oauthDienste = [];

    public VersandwegTests()
    {
        _verbindung = new SqliteConnection("DataSource=:memory:");
        _verbindung.Open();
        _db = new AutomationDbContext(new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_verbindung)
            .Options);
        _db.Database.EnsureCreated();

        _anhangPfad = Path.Combine(Path.GetTempPath(), $"anspruchsschreiben_{Guid.NewGuid():N}.pdf");
        File.WriteAllText(_anhangPfad, "kein echtes PDF, nur Gewicht");
    }

    public void Dispose()
    {
        foreach (var dienst in _oauthDienste)
        {
            dienst.Dispose();
        }

        _db.Dispose();
        _verbindung.Dispose();
        if (File.Exists(_anhangPfad))
        {
            File.Delete(_anhangPfad);
        }
    }

    /// <summary>Faengt die Nachricht ab, statt sie einzuliefern.</summary>
    private sealed class FalscherTransport : ISmtpUebergabe
    {
        public MimeMessage? Eingeliefert { get; private set; }

        /// <summary>Wenn gesetzt, scheitert die Einlieferung damit.</summary>
        public EmailVersandException? Scheitert { get; set; }

        public Task UebergebeAsync(MimeMessage mime, SmtpZugang zugang, CancellationToken cancellationToken)
        {
            if (Scheitert is not null)
            {
                throw Scheitert;
            }

            Eingeliefert = mime;
            return Task.CompletedTask;
        }
    }

    private sealed class FalscheGesendetAblage : IGesendetOrdnerAblage
    {
        public bool Gelingt { get; set; } = true;

        public bool Versucht { get; private set; }

        public Task<bool> LegeAbAsync(MimeMessage nachricht, SmtpZugang zugang, CancellationToken cancellationToken)
        {
            Versucht = true;
            return Task.FromResult(Gelingt);
        }
    }

    /// <summary>
    /// Der hinterlegte Zugang -- ohne <see cref="MailboxConfigStore"/>, der im
    /// Konstruktor das echte %APPDATA% des Rechners liest.
    /// </summary>
    private sealed class FesterZugang(MailboxOptions current) : IMailboxConfigSource
    {
        public MailboxOptions Current { get; } = current;
    }

    /// <summary>
    /// Ein vollstaendig eingerichtetes IONOS-Postfach. Kein Gmail: dort legt
    /// der Anbieter die Kopie selbst ab, und die Ablage wuerde uebersprungen.
    /// </summary>
    private static MailboxOptions Postfach() => new()
    {
        Enabled = true,
        Host = "imap.ionos.de",
        Port = 993,
        UseSsl = true,
        Username = "kanzlei@example.de",
        AppPassword = "geheim",
    };

    private SmtpEmailVersender Versender(MailboxOptions? postfach = null)
    {
        var zugang = new FesterZugang(postfach ?? Postfach());
        var oauth = new MicrosoftMailOAuthService(zugang, NullLogger<MicrosoftMailOAuthService>.Instance);
        _oauthDienste.Add(oauth);

        return new SmtpEmailVersender(
            zugang,
            oauth,
            _gesendet,
            _transport,
            new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance),
            new KanzleiSignatur(_db, new SignaturAblage(NullLogger<SignaturAblage>.Instance)),
            Options.Create(new EmailVersandOptions()),
            NullLogger<SmtpEmailVersender>.Instance);
    }

    /// <summary>
    /// Der Anhang geht unter einem anderen Namen hinaus, als er auf der Platte
    /// traegt -- genau die Unterscheidung, die im Protokoll zaehlt.
    /// </summary>
    private EmailNachricht Nachricht() => new(
        An: ["schaden@huk.de"],
        Kopie: ["mandant@example.de"],
        Betreff: "Anspruchsschreiben HG-E 1427",
        Text: "Sehr geehrte Damen und Herren,",
        AnhangPfade: [_anhangPfad],
        AbsenderName: "Kanzlei Ahmad",
        AnhangNamen: new Dictionary<string, string>
        {
            [_anhangPfad] = "Anspruchsschreiben Müller.pdf",
        },
        VorgangReferenz: "84/26 C03_HG-E 1427");

    [Fact]
    public async Task Ein_geglueckter_Versand_geht_hinaus_und_steht_im_Protokoll()
    {
        var ergebnis = await Versender().SendeAsync(Nachricht(), CancellationToken.None);

        _transport.Eingeliefert.Should().NotBeNull();
        _transport.Eingeliefert!.To.Mailboxes.Select(m => m.Address)
            .Should().ContainSingle().Which.Should().Be("schaden@huk.de");
        ergebnis.ImGesendetOrdner.Should().BeTrue();
        ergebnis.Hinweis.Should().BeNull();

        var protokoll = await new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance)
            .ZuAsync("84/26 C03_HG-E 1427", CancellationToken.None);
        protokoll.Should().ContainSingle();
        protokoll[0].Weg.Should().Be(VersandWeg.Direktversand);
        protokoll[0].MessageId.Should().Be(_transport.Eingeliefert.MessageId);
    }

    [Fact]
    public async Task Der_Anhangname_im_Protokoll_ist_der_versendete_nicht_der_auf_der_Platte()
    {
        // §4.7: Umbenannt wird nur fuer die Mail; die Datei in der Akte behaelt
        // ihren Namen. Als Nachweis zaehlt, was der Empfaenger bekommen hat.
        await Versender().SendeAsync(Nachricht(), CancellationToken.None);

        var protokoll = await new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance)
            .ZuAsync("84/26 C03_HG-E 1427", CancellationToken.None);

        protokoll[0].Anhaenge.Should().ContainSingle()
            .Which.Should().Be("Anspruchsschreiben Müller.pdf");
    }

    [Fact]
    public async Task Eine_misslungene_Kopie_in_Gesendet_haelt_den_Versand_nicht_auf()
    {
        // Die Mail ist beim Empfaenger. Ein Fehlschlag beim Nachtragen darf
        // weder werfen noch den Protokolleintrag verhindern -- sonst haette der
        // Anwalt einen Versand ohne jeden Nachweis.
        _gesendet.Gelingt = false;

        var ergebnis = await Versender().SendeAsync(Nachricht(), CancellationToken.None);

        ergebnis.ImGesendetOrdner.Should().BeFalse();
        ergebnis.Hinweis.Should().NotBeNullOrWhiteSpace();

        var protokoll = await new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance)
            .ZuAsync("84/26 C03_HG-E 1427", CancellationToken.None);
        protokoll.Should().ContainSingle();
        protokoll[0].ImGesendetOrdner.Should().BeFalse();
    }

    [Fact]
    public async Task Eine_gescheiterte_Einlieferung_protokolliert_nichts()
    {
        // Der wichtigste der vier: Ein Protokoll, das Mails verzeichnet, die nie
        // hinausgingen, ist als Nachweis wertlos. Und die Kopie in "Gesendet"
        // darf gar nicht erst versucht werden.
        _transport.Scheitert = new EmailVersandException(
            EmailVersandFehler.Server,
            "Der Postausgangsserver ist nicht erreichbar.");

        var versender = Versender();
        await FluentActions.Awaiting(() => versender.SendeAsync(Nachricht(), CancellationToken.None))
            .Should().ThrowAsync<EmailVersandException>();

        _gesendet.Versucht.Should().BeFalse();
        var protokoll = await new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance)
            .ZuAsync("84/26 C03_HG-E 1427", CancellationToken.None);
        protokoll.Should().BeEmpty();
    }

    [Fact]
    public async Task Ohne_hinterlegten_Zugang_geht_nichts_hinaus()
    {
        // Der Zugang wird vor allem anderen geprueft: Was der Anwalt selbst
        // beheben kann, soll scheitern, bevor irgendetwas das Haus verlaesst.
        var versender = Versender(new MailboxOptions());

        var fehler = await FluentActions
            .Awaiting(() => versender.SendeAsync(Nachricht(), CancellationToken.None))
            .Should().ThrowAsync<EmailVersandException>();

        fehler.Which.Grund.Should().Be(EmailVersandFehler.KeinZugang);
        _transport.Eingeliefert.Should().BeNull();
    }
}
