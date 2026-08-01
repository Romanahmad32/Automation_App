using AutomationService.Core.Persistence;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.Versicherer.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Persistence;
using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft den DB-gestützten Antwort-Speicher gegen eine echte In-Memory-SQLite:
/// Anlegen/Dublettenprüfung/Quittieren wie zuvor, plus die zwei neuen Garantien —
/// die Treffer überdauern einen „Neustart" (zweiter Kontext auf derselben
/// Verbindung) und werden best-effort per Referenz mit einem Vorgang verknüpft.
/// </summary>
public sealed class ReceivedReplyStoreTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly AutomationDbContext _db;
    private readonly DbReceivedReplyStore _store;

    public ReceivedReplyStoreTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        _db = NewContext();
        _db.Database.EnsureCreated();
        _store = NewStore(_db);
    }

    private AutomationDbContext NewContext()
    {
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        return new AutomationDbContext(options);
    }

    private static DbReceivedReplyStore NewStore(AutomationDbContext db) =>
        new(db, new VorgangRepository(db), new VersichererWissen(db));

    private static ZentralrufReplyData SampleData(string referenz = "84/26 C03_GG-XY 123") =>
        new() { Referenz = referenz, VersichererName = "HUK-COBURG" };

    [Fact]
    public async Task AddAsync_NeuerSchluessel_LegtTrefferAnUndVergibtId()
    {
        var reply = await _store.AddAsync("msg-1", SampleData(), "Antwort von Zentralruf", "noreply@gdv-dl.de", []);

        reply.Should().NotBeNull();
        reply!.Id.Should().NotBeNullOrWhiteSpace();
        reply.Acknowledged.Should().BeFalse();
        reply.Data.VersichererName.Should().Be("HUK-COBURG");
        (await _store.CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task AddAsync_GleicherSchluessel_WirdNichtDoppeltErfasst()
    {
        await _store.AddAsync("msg-1", SampleData(), "Betreff", "from", []);

        var second = await _store.AddAsync("msg-1", SampleData(), "Betreff", "from", []);

        second.Should().BeNull();
        (await _store.CountAsync()).Should().Be(1);
        (await _store.ContainsAsync("msg-1")).Should().BeTrue();
    }

    [Fact]
    public async Task GetAllAsync_FiltertQuittierteHeraus_WennNichtAngefordert()
    {
        var first = (await _store.AddAsync("msg-1", SampleData(), "a", "from", []))!;
        await _store.AddAsync("msg-2", SampleData("85/26 C03_GG-XY 123"), "b", "from", []);

        (await _store.AcknowledgeAsync(first.Id)).Should().BeTrue();

        (await _store.GetAllAsync(includeAcknowledged: false)).Should().ContainSingle()
            .Which.Id.Should().NotBe(first.Id);
        (await _store.GetAllAsync(includeAcknowledged: true)).Should().HaveCount(2);
    }

    [Fact]
    public async Task AcknowledgeAsync_UnbekannteId_GibtFalse()
    {
        (await _store.AcknowledgeAsync("999")).Should().BeFalse();
        (await _store.AcknowledgeAsync("keine-zahl")).Should().BeFalse();
    }

    [Fact]
    public async Task AddAsync_UeberdauertNeustart_DublettenpruefungGreiftWeiter()
    {
        await _store.AddAsync("msg-1", SampleData(), "Betreff", "from", []);

        // Zweiter Kontext auf derselben (offenen) Verbindung = simulierter Neustart
        // mit erhaltener Datei: der frühere Treffer ist weiterhin bekannt.
        await using var freshContext = NewContext();
        var freshStore = NewStore(freshContext);

        (await freshStore.ContainsAsync("msg-1")).Should().BeTrue();
        (await freshStore.CountAsync()).Should().Be(1);
    }

    [Fact]
    public async Task AddAsync_PassendeReferenz_VerknuepftVorgangOhneIhnZuAendern()
    {
        _db.Vorgaenge.Add(new VorgangEntity
        {
            Referenz = "84/26 C03_GG-XY 123",
            AngefragtAm = DateTime.UnixEpoch,
            Status = "angefragt",
            Rechtsgebiet = "verkehrsrecht",
        });
        await _db.SaveChangesAsync();

        await _store.AddAsync("msg-1", SampleData(), "Betreff", "from", []);

        var gespeichert = await _db.ReceivedReplies.SingleAsync();
        gespeichert.Zugeordnet.Should().BeTrue();
        gespeichert.VorgangId.Should().NotBeNull();

        // Der Vorgang selbst bleibt unberührt — Übernehmen ist der Frontend-Schritt.
        var vorgang = await _db.Vorgaenge.SingleAsync();
        vorgang.Status.Should().Be("angefragt");
        vorgang.AntwortJson.Should().BeNull();
    }

    [Fact]
    public async Task AddAsync_OhnePassendenVorgang_BleibtUnzugeordnet()
    {
        await _store.AddAsync("msg-1", SampleData("99/26 C03_XX-YZ 1"), "Betreff", "from", []);

        var gespeichert = await _db.ReceivedReplies.SingleAsync();
        gespeichert.Zugeordnet.Should().BeFalse();
        gespeichert.VorgangId.Should().BeNull();
        gespeichert.ZuordnungVermutet.Should().BeFalse();
    }

    [Fact]
    public async Task AddAsync_VerstuemmelteReferenz_VermutetVorgangUeberKennzeichenUndUnfalldatum()
    {
        _db.Vorgaenge.Add(new VorgangEntity
        {
            Referenz = "84/26 C03_GG-XY 123",
            AngefragtAm = DateTime.UnixEpoch,
            Status = "angefragt",
            Rechtsgebiet = "verkehrsrecht",
            Kennzeichen = "GG-XY 123",
            UnfallDatum = "01.06.2026",
        });
        await _db.SaveChangesAsync();

        var data = new ZentralrufReplyData
        {
            Referenz = "84/2 C03_GG-XY 12", // in der Mail verstümmelt
            Kennzeichen = "GG-XY 123",
            UnfallDatum = "01.06.2026",
            VersichererName = "HUK-COBURG",
        };
        await _store.AddAsync("msg-1", data, "Betreff", "from", []);

        var gespeichert = await _db.ReceivedReplies.SingleAsync();
        gespeichert.Zugeordnet.Should().BeFalse();
        gespeichert.ZuordnungVermutet.Should().BeTrue();
        gespeichert.VorgangId.Should().NotBeNull();

        // Auch die vermutete Zuordnung ändert den Vorgang nicht.
        (await _db.Vorgaenge.SingleAsync()).AntwortJson.Should().BeNull();
    }

    [Fact]
    public async Task AddAsync_MehrdeutigerFallbackTreffer_SetztKeineVermutung()
    {
        foreach (var referenz in new[] { "84/26 C03_GG-XY 123", "85/26 C03_GG-XY 123" })
        {
            _db.Vorgaenge.Add(new VorgangEntity
            {
                Referenz = referenz,
                AngefragtAm = DateTime.UnixEpoch,
                Status = "angefragt",
                Rechtsgebiet = "verkehrsrecht",
                Kennzeichen = "GG-XY 123",
                UnfallDatum = "01.06.2026",
            });
        }
        await _db.SaveChangesAsync();

        var data = new ZentralrufReplyData
        {
            Kennzeichen = "GG-XY 123",
            UnfallDatum = "01.06.2026",
        };
        await _store.AddAsync("msg-1", data, "Betreff", "from", []);

        var gespeichert = await _db.ReceivedReplies.SingleAsync();
        gespeichert.ZuordnungVermutet.Should().BeFalse();
        gespeichert.VorgangId.Should().BeNull();
    }

    [Fact]
    public async Task AddAsync_LerntVersichererInDieWissensbasis()
    {
        var data = new ZentralrufReplyData
        {
            VersichererName = "HUK-COBURG",
            VersichererOrt = "Coburg",
            VersichererEmail = "schaden@huk.de",
        };
        await _store.AddAsync("msg-1", data, "Betreff", "from", []);

        var eintrag = await _db.Versicherer.SingleAsync();
        eintrag.Name.Should().Be("HUK-COBURG");
        eintrag.Email.Should().Be("schaden@huk.de");
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
