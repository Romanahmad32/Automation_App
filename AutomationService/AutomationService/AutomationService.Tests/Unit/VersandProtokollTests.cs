using AutomationService.Core.Persistence;
using AutomationService.Features.EmailVersand.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Versandnachweis am Vorgang (§4.7): wann, an wen, mit welchen Anhängen.
///
/// Für eine Kanzlei ist das der Beleg, dass das Anspruchsschreiben hinaus ist.
/// Zwei Eigenschaften entscheiden über seinen Wert: Er muss den
/// <b>Direktversand</b> von der bloßen <b>Übergabe</b> an Outlook
/// unterscheiden — bei der die App gar nicht weiß, ob gesendet wurde (§4.8) —,
/// und er darf den Versand nie aufhalten.
/// </summary>
public sealed class VersandProtokollTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly VersandProtokoll _protokoll;

    public VersandProtokollTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
        _protokoll = new VersandProtokoll(_db, NullLogger<VersandProtokoll>.Instance);
    }

    private static VersandEintrag Eintrag(
        string referenz = "84/26 C03_HG-E 1427",
        VersandWeg weg = VersandWeg.Direktversand,
        int minuten = 0) =>
        new(
            referenz,
            new DateTimeOffset(2026, 8, 28, 14, minuten, 0, TimeSpan.FromHours(2)),
            weg,
            "kanzlei@example.de",
            ["schaden@huk.de"],
            ["mandant@example.de"],
            "Anspruchsschreiben",
            ["Anspruchsschreiben.pdf"],
            ImGesendetOrdner: true,
            MessageId: "<abc@example.de>");

    [Fact]
    public async Task SchreibtUndLiestDenGanzenEintrag()
    {
        await _protokoll.SchreibeAsync(Eintrag(), CancellationToken.None);

        var gelesen = await _protokoll.ZuAsync(
            "84/26 C03_HG-E 1427",
            CancellationToken.None);

        gelesen.Should().HaveCount(1);
        var eintrag = gelesen[0];
        eintrag.Empfaenger.Should().Equal("schaden@huk.de");
        eintrag.Kopie.Should().Equal("mandant@example.de");
        // Der Name, unter dem der Anhang hinausging -- danach sucht, wer
        // spaeter nachsieht.
        eintrag.Anhaenge.Should().Equal("Anspruchsschreiben.pdf");
        eintrag.MessageId.Should().Be("<abc@example.de>");
        eintrag.ImGesendetOrdner.Should().BeTrue();
        eintrag.GesendetAm.UtcDateTime.Should().Be(new DateTime(2026, 8, 28, 12, 0, 0));
    }

    [Fact]
    public async Task OhneVorgangsreferenzEntstehtKeinEintrag()
    {
        // Der Dialog laesst sich auch ohne Vorgang oeffnen. Ein Eintrag ohne
        // Akte waere nirgends wiederzufinden.
        await _protokoll.SchreibeAsync(
            Eintrag(referenz: "   "),
            CancellationToken.None);

        _db.Versandprotokoll.Should().BeEmpty();
    }

    [Fact]
    public async Task DerJuengsteVersandStehtVorn()
    {
        await _protokoll.SchreibeAsync(Eintrag(minuten: 0), CancellationToken.None);
        await _protokoll.SchreibeAsync(Eintrag(minuten: 30), CancellationToken.None);

        var gelesen = await _protokoll.ZuAsync(
            "84/26 C03_HG-E 1427",
            CancellationToken.None);

        gelesen.Should().HaveCount(2);
        gelesen[0].GesendetAm.Minute.Should().Be(30);
    }

    [Fact]
    public async Task DieUebergabeAnOutlookBleibtAlsSolcheErkennbar()
    {
        // Sie ist kein Versandnachweis: Ob dort gesendet wurde, weiss die App
        // nicht (§4.8). Ginge der Unterschied verloren, waere das Protokoll
        // schlechter als keines.
        await _protokoll.SchreibeAsync(
            Eintrag(weg: VersandWeg.OutlookEntwurf),
            CancellationToken.None);

        var gelesen = await _protokoll.ZuAsync(
            "84/26 C03_HG-E 1427",
            CancellationToken.None);

        gelesen[0].Weg.Should().Be(VersandWeg.OutlookEntwurf);
    }

    [Fact]
    public async Task LetzteJeVorgang_LiefertProVorgangGenauEinen()
    {
        await _protokoll.SchreibeAsync(Eintrag(minuten: 0), CancellationToken.None);
        await _protokoll.SchreibeAsync(Eintrag(minuten: 45), CancellationToken.None);
        await _protokoll.SchreibeAsync(
            Eintrag(referenz: "85/26 C03_HG-E 9999"),
            CancellationToken.None);

        var letzte = await _protokoll.LetzteJeVorgangAsync(CancellationToken.None);

        letzte.Should().HaveCount(2);
        letzte.Single(e => e.VorgangReferenz.StartsWith("84/26", StringComparison.Ordinal))
            .GesendetAm.Minute.Should().Be(45);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
