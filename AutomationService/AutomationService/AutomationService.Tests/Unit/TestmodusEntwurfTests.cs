using AutomationService.Core.Persistence;
using AutomationService.Features.DevSimulation.Domain.Services;
using AutomationService.Features.EmailVersand.Domain.Services;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MimeKit;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Entwurf im E2E-Testmodus (#168), durch den <b>echten</b>
/// <see cref="EntwurfOeffner"/>: Outlook ist nicht da, also nimmt er den
/// Dateiweg; die <c>.eml</c> entsteht, geöffnet wird nichts — und das
/// Versandprotokoll der Datenbank bekommt seinen Eintrag wie in der Kanzlei.
/// Genau dafür sitzt die Naht unter dem Öffner und nicht an seiner Stelle.
/// </summary>
public sealed class TestmodusEntwurfTests : IDisposable
{
    private const string Referenz = "84/26 C03_HG-E 1427";

    private readonly TestmodusUmgebung _umgebung = new();
    private readonly SqliteConnection _verbindung;
    private readonly AutomationDbContext _db;
    private readonly MailboxConfigStore _zugang = new(
        Options.Create(new MailboxOptions()),
        NullLogger<MailboxConfigStore>.Instance);

    public TestmodusEntwurfTests()
    {
        _verbindung = new SqliteConnection("DataSource=:memory:");
        _verbindung.Open();
        _db = new AutomationDbContext(new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_verbindung)
            .Options);
        _db.Database.EnsureCreated();
    }

    public void Dispose()
    {
        _zugang.Dispose();
        _db.Dispose();
        _verbindung.Dispose();
        _umgebung.Dispose();
    }

    private EntwurfOeffner Oeffner() => new(
        _zugang,
        new TestmodusOutlook(),
        new TestmodusEntwurfDatei(_umgebung.Ordner, _umgebung.Protokoll, NullLogger<TestmodusEntwurfDatei>.Instance),
        new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance),
        Options.Create(new EmailVersandOptions()));

    private EmailNachricht Nachricht() => new(
        An: ["schaden@versicherer.invalid"],
        Kopie: [],
        Betreff: "Anspruchsschreiben HG-E 1427",
        Text: "Sehr geehrte Damen und Herren,",
        AnhangPfade: [_umgebung.Eingabedatei("schreiben.pdf", "kein echtes PDF")],
        AbsenderName: "Kanzlei Muster",
        VorgangReferenz: Referenz);

    [Fact]
    public async Task Der_Entwurf_nimmt_den_Dateiweg_und_hinterlaesst_die_eml()
    {
        var ergebnis = await Oeffner().OeffneAsync(Nachricht(), CancellationToken.None);

        ergebnis.Weg.Should().Be(EntwurfWeg.Datei);
        var zeile = _umgebung.Zeilen().Should().ContainSingle().Subject;
        zeile.Aktion.Should().Be("entwurf");
        zeile.Referenz.Should().BeNull("an der Naht der Entwurfsdatei ist der Vorgang nicht bekannt");
        zeile.Datei.Should().StartWith("Entwuerfe/").And.EndWith(".eml");

        using var entwurf = await MimeMessage.LoadAsync(_umgebung.VollerPfad(zeile.Datei!));
        entwurf.Subject.Should().Be("Anspruchsschreiben HG-E 1427");
        entwurf.To.Mailboxes.Select(adresse => adresse.Address).Should().Equal("schaden@versicherer.invalid");
        entwurf.Attachments.Should().ContainSingle();
    }

    [Fact]
    public async Task Das_Versandprotokoll_entsteht_wie_in_der_Kanzlei()
    {
        await Oeffner().OeffneAsync(Nachricht(), CancellationToken.None);

        var protokoll = await new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance)
            .ZuAsync(Referenz, CancellationToken.None);
        protokoll.Should().ContainSingle().Which.Weg.Should().Be(VersandWeg.Entwurfsdatei);
    }

    /// <summary>
    /// Scheitert das Schreiben, sagt die Attrappe es wie der echte Weg — und
    /// der Öffner bricht mit seiner Meldung ab, statt einen Entwurf zu melden,
    /// den es nicht gibt.
    /// </summary>
    [Fact]
    public async Task Ein_unschreibbarer_Ordner_endet_als_Meldung_nicht_als_Entwurf()
    {
        Directory.CreateDirectory(_umgebung.Ordner.Wurzel);
        await File.WriteAllTextAsync(Path.Combine(_umgebung.Ordner.Wurzel, TestmodusOrdner.Entwuerfe), "eine Datei, kein Ordner");

        var oeffnen = () => Oeffner().OeffneAsync(Nachricht(), CancellationToken.None);

        await oeffnen.Should().ThrowAsync<EmailVersandException>();
        var protokoll = await new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance)
            .ZuAsync(Referenz, CancellationToken.None);
        protokoll.Should().BeEmpty();
    }
}
